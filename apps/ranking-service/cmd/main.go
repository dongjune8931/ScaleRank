package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	goredis "github.com/redis/go-redis/v9"
	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	httpAdapter "github.com/dongjune8931/scalerank/apps/ranking-service/internal/adapter/in/http"
	noopCache "github.com/dongjune8931/scalerank/apps/ranking-service/internal/adapter/out/cache/noop"
	redisCache "github.com/dongjune8931/scalerank/apps/ranking-service/internal/adapter/out/cache/redis"
	resilientCache "github.com/dongjune8931/scalerank/apps/ranking-service/internal/adapter/out/cache/resilient"
	"github.com/dongjune8931/scalerank/apps/ranking-service/internal/adapter/out/persistence"
	rankingApp "github.com/dongjune8931/scalerank/apps/ranking-service/internal/application/ranking"
	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
	"github.com/dongjune8931/scalerank/apps/ranking-service/internal/infrastructure"
)

type scoreRecord struct {
	UserID    string    `gorm:"primaryKey;column:user_id"`
	Score     uint64    `gorm:"column:score;type:bigint unsigned"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime"`
}

func (scoreRecord) TableName() string { return "scores" }

func main() {
	cfg := infrastructure.Load()

	shutdown := infrastructure.InitTracer("ranking-service", cfg.OTelEndpoint)
	defer shutdown(context.Background())

	// Init MySQL
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=UTC",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName,
	)
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("failed to get sql.DB: %v", err)
	}
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(5 * time.Minute)
	sqlDB.SetConnMaxIdleTime(2 * time.Minute)
	if err := db.AutoMigrate(&scoreRecord{}); err != nil {
		log.Fatalf("failed to auto-migrate: %v", err)
	}
	log.Println("database connected and migrated")

	// Build persistence adapter
	mysqlRepo := persistence.NewMySQLRepository(db)

	// Init cache adapters
	noop := noopCache.NewNoopCache()
	var primaryCache rankingDomain.Cache = noop

	var redisClient *goredis.Client

	if cfg.RedisHost != "" {
		redisClient = goredis.NewClient(&goredis.Options{
			Addr: fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
		})
		pingCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		if err := redisClient.Ping(pingCtx).Err(); err != nil {
			cancel()
			log.Printf("redis not reachable, using noop cache: %v", err)
		} else {
			cancel()
			primaryCache = redisCache.NewRedisCache(redisClient)
			log.Println("redis connected")
		}
	} else {
		log.Println("REDIS_HOST not set, using noop cache")
	}

	// Build resilient cache
	rc := resilientCache.NewResilientCache(primaryCache, noop)

	// Build use case
	usecase := rankingApp.NewRankingUseCase(rc, mysqlRepo)

	// Build HTTP handler and register routes
	router := gin.Default()
	router.Use(otelgin.Middleware("ranking-service"))
	handler := httpAdapter.NewRankingHandler(usecase)
	handler.RegisterRoutes(router)

	// Start background services
	bgCtx, bgCancel := context.WithCancel(context.Background())
	defer bgCancel()

	rc.Start(bgCtx)

	// Start HTTP server
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%s", cfg.Port),
		Handler: router,
	}

	go func() {
		log.Printf("ranking-service listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Graceful shutdown on SIGINT/SIGTERM
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("server shutdown error: %v", err)
	}

	rc.Stop()

	if redisClient != nil {
		if err := redisClient.Close(); err != nil {
			log.Printf("redis close error: %v", err)
		}
	}

	log.Println("shutdown complete")
}
