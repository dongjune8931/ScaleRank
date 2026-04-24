package score

import "context"

type Repository interface {
	BatchUpsertScores(ctx context.Context, scores map[string]uint64) error
}

type Cache interface {
	UpdateScore(ctx context.Context, userID string, score uint64) error
	PopStagingScores(ctx context.Context) (map[string]uint64, error)
	IsHealthy(ctx context.Context) bool
}
