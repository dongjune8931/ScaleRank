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

	httpAdapter "github.com/dongjune8931/scalerank/apps/score-service/internal/adapter/in/http"
	noopCache "github.com/dongjune8931/scalerank/apps/score-service/internal/adapter/out/cache/noop"
	redisCache "github.com/dongjune8931/scalerank/apps/score-service/internal/adapter/out/cache/redis"
	resilientCache "github.com/dongjune8931/scalerank/apps/score-service/internal/adapter/out/cache/resilient"
	"github.com/dongjune8931/scalerank/apps/score-service/internal/adapter/out/persistence"
	scoreApp "github.com/dongjune8931/scalerank/apps/score-service/internal/application/score"
	syncApp "github.com/dongjune8931/scalerank/apps/score-service/internal/application/sync"
	scoreDomain "github.com/dongjune8931/scalerank/apps/score-service/internal/domain/score"
	"github.com/dongjune8931/scalerank/apps/score-service/internal/infrastructure"
)

type scoreRecord struct {
	UserID    string    `gorm:"primaryKey;column:user_id"`
	Score     float64   `gorm:"column:score"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime"`
}

func (scoreRecord) TableName() string { return "scores" }

func main() {
	cfg := infrastructure.Load()

	shutdown := infrastructure.InitTracer("score-service", cfg.OTelEndpoint)
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
	if err := db.AutoMigrate(&scoreRecord{}); err != nil {
		log.Fatalf("failed to auto-migrate: %v", err)
	}
	log.Println("database connected and migrated")

	// Build persistence adapter
	mysqlRepo := persistence.NewMySQLRepository(db)

	// Init cache adapters
	noop := noopCache.NewNoopCache()
	var primaryCache scoreDomain.Cache = noop

	var redisAvailable bool
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
			redisAvailable = true
			log.Println("redis connected")
		}
	} else {
		log.Println("REDIS_HOST not set, using noop cache")
	}

	// Build resilient cache
	rc := resilientCache.NewResilientCache(primaryCache, noop)

	// Build use case
	usecase := scoreApp.NewScoreUseCase(rc)

	// Build sync service (only when Redis is available)
	var syncSvc *syncApp.SyncService
	if redisAvailable {
		syncSvc = syncApp.NewSyncService(rc, mysqlRepo)
	}

	// Build HTTP handler and register routes
	router := gin.Default()
	router.Use(otelgin.Middleware("score-service"))
	handler := httpAdapter.NewScoreHandler(usecase)
	handler.RegisterRoutes(router)

	// Start background services
	bgCtx, bgCancel := context.WithCancel(context.Background())
	defer bgCancel()

	rc.Start(bgCtx)

	if syncSvc != nil {
		syncSvc.Start(bgCtx)
	}

	// Start HTTP server
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%s", cfg.Port),
		Handler: router,
	}

	go func() {
		log.Printf("score-service listening on :%s", cfg.Port)
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

	if syncSvc != nil {
		syncSvc.Stop()
	}
	rc.Stop()

	if redisClient != nil {
		if err := redisClient.Close(); err != nil {
			log.Printf("redis close error: %v", err)
		}
	}

	log.Println("shutdown complete")
}
