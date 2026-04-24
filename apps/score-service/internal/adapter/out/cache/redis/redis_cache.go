package redis

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
)

const (
	leaderboardGlobal  = "leaderboard:global"
	stagingKey         = "score:staging"
	syncingKey         = "score:syncing"
)

type RedisCache struct {
	client *redis.Client
}

func NewRedisCache(client *redis.Client) *RedisCache {
	return &RedisCache{client: client}
}

func (r *RedisCache) UpdateScore(ctx context.Context, userID string, score uint64) error {
	tracer := otel.Tracer("score-service")
	ctx, span := tracer.Start(ctx, "redis.zadd")
	defer span.End()
	span.SetAttributes(attribute.String("user.id", userID), attribute.Int64("score", int64(score)))

	now := time.Now().UTC()

	pipe := r.client.Pipeline()

	pipe.ZAddGT(ctx, leaderboardGlobal, redis.Z{Score: float64(score), Member: userID})

	pipe.HSet(ctx, stagingKey, userID, strconv.FormatUint(score, 10))

	dailyKey := fmt.Sprintf("leaderboard:daily:%s", now.Format("20060102"))
	pipe.ZAddGT(ctx, dailyKey, redis.Z{Score: float64(score), Member: userID})
	endOfDay := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, 0, time.UTC)
	pipe.Expire(ctx, dailyKey, time.Until(endOfDay)+time.Hour)

	year, week := now.ISOWeek()
	weeklyKey := fmt.Sprintf("leaderboard:weekly:%d%02d", year, week)
	pipe.ZAddGT(ctx, weeklyKey, redis.Z{Score: float64(score), Member: userID})
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	daysUntilEndOfWeek := 7 - weekday
	endOfWeek := time.Date(now.Year(), now.Month(), now.Day()+daysUntilEndOfWeek, 23, 59, 59, 0, time.UTC)
	pipe.Expire(ctx, weeklyKey, time.Until(endOfWeek)+time.Hour)

	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("update score pipeline: %w", err)
	}
	return nil
}

func (r *RedisCache) PopStagingScores(ctx context.Context) (map[string]uint64, error) {
	if err := r.client.Rename(ctx, stagingKey, syncingKey).Err(); err != nil {
		if err == redis.Nil || err.Error() == "ERR no such key" {
			return map[string]uint64{}, nil
		}
		return nil, fmt.Errorf("rename staging key: %w", err)
	}

	raw, err := r.client.HGetAll(ctx, syncingKey).Result()
	if err != nil {
		return nil, fmt.Errorf("hgetall syncing key: %w", err)
	}

	if err := r.client.Del(ctx, syncingKey).Err(); err != nil {
		return nil, fmt.Errorf("del syncing key: %w", err)
	}

	scores := make(map[string]uint64, len(raw))
	for userID, val := range raw {
		v, err := strconv.ParseUint(val, 10, 64)
		if err != nil {
			continue
		}
		scores[userID] = v
	}
	return scores, nil
}

func (r *RedisCache) IsHealthy(ctx context.Context) bool {
	return r.client.Ping(ctx).Err() == nil
}
