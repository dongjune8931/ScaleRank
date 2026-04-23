package score

import "context"

type Repository interface {
	BatchUpsertScores(ctx context.Context, scores map[string]float64) error
}

type Cache interface {
	UpdateScore(ctx context.Context, userID string, score float64) error
	PopStagingScores(ctx context.Context) (map[string]float64, error)
	IsHealthy(ctx context.Context) bool
}
