package redis

import (
	"context"
	"fmt"
	"math"

	"github.com/redis/go-redis/v9"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"

	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
)

func safeUint64(f float64) uint64 {
	if f < 0 {
		return 0
	}
	return uint64(math.Round(f))
}

const leaderboardGlobal = "leaderboard:global"

type RedisCache struct {
	client *redis.Client
}

func NewRedisCache(client *redis.Client) *RedisCache {
	return &RedisCache{client: client}
}

func (r *RedisCache) GetTopN(ctx context.Context, leaderboard string, n int64) ([]rankingDomain.RankEntry, error) {
	tracer := otel.Tracer("ranking-service")
	ctx, span := tracer.Start(ctx, "redis.zrevrange")
	defer span.End()
	span.SetAttributes(attribute.String("leaderboard", leaderboard), attribute.Int64("limit", n))

	results, err := r.client.ZRevRangeWithScores(ctx, leaderboard, 0, n-1).Result()
	if err != nil {
		return nil, fmt.Errorf("zrevrange %s: %w", leaderboard, err)
	}

	entries := make([]rankingDomain.RankEntry, 0, len(results))
	for i, z := range results {
		entries = append(entries, rankingDomain.RankEntry{
			UserID: z.Member.(string),
			Score:  safeUint64(z.Score),
			Rank:   int64(i) + 1,
		})
	}
	return entries, nil
}

func (r *RedisCache) GetUserRank(ctx context.Context, leaderboard string, userID string) (*rankingDomain.RankEntry, error) {
	tracer := otel.Tracer("ranking-service")
	ctx, span := tracer.Start(ctx, "redis.zrevrank")
	defer span.End()
	span.SetAttributes(attribute.String("user.id", userID))

	pipe := r.client.Pipeline()
	rankCmd := pipe.ZRevRank(ctx, leaderboard, userID)
	scoreCmd := pipe.ZScore(ctx, leaderboard, userID)

	if _, err := pipe.Exec(ctx); err != nil && err != redis.Nil {
		return nil, fmt.Errorf("pipeline get user rank %s: %w", userID, err)
	}

	rank, err := rankCmd.Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("zrevrank %s: %w", userID, err)
	}

	score, err := scoreCmd.Result()
	if err != nil {
		return nil, fmt.Errorf("zscore %s: %w", userID, err)
	}

	return &rankingDomain.RankEntry{
		UserID: userID,
		Score:  safeUint64(score),
		Rank:   rank + 1,
	}, nil
}

func (r *RedisCache) IsHealthy(ctx context.Context) bool {
	return r.client.Ping(ctx).Err() == nil
}
