package ranking

import "context"

type Cache interface {
	GetTopN(ctx context.Context, leaderboard string, n int64) ([]RankEntry, error)
	GetUserRank(ctx context.Context, leaderboard string, userID string) (*RankEntry, error)
	IsHealthy(ctx context.Context) bool
}

type Repository interface {
	GetTopN(ctx context.Context, n int64) ([]RankEntry, error)
	GetUserRank(ctx context.Context, userID string) (*RankEntry, error)
}
