package redis

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"

	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
)

const leaderboardGlobal = "leaderboard:global"

type RedisCache struct {
	client *redis.Client
}

func NewRedisCache(client *redis.Client) *RedisCache {
	return &RedisCache{client: client}
}

func (r *RedisCache) GetTopN(ctx context.Context, leaderboard string, n int64) ([]rankingDomain.RankEntry, error) {
	results, err := r.client.ZRevRangeWithScores(ctx, leaderboard, 0, n-1).Result()
	if err != nil {
		return nil, fmt.Errorf("zrevrange %s: %w", leaderboard, err)
	}

	entries := make([]rankingDomain.RankEntry, 0, len(results))
	for i, z := range results {
		entries = append(entries, rankingDomain.RankEntry{
			UserID: z.Member.(string),
			Score:  z.Score,
			Rank:   int64(i) + 1,
		})
	}
	return entries, nil
}

func (r *RedisCache) GetUserRank(ctx context.Context, leaderboard string, userID string) (*rankingDomain.RankEntry, error) {
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
		Score:  score,
		Rank:   rank + 1,
	}, nil
}

func (r *RedisCache) IsHealthy(ctx context.Context) bool {
	return r.client.Ping(ctx).Err() == nil
}
