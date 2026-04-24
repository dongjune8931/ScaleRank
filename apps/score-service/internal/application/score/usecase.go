package score

import (
	"context"
	"fmt"

	scoreDomain "github.com/dongjune8931/scalerank/apps/score-service/internal/domain/score"
)

type ScoreUseCase struct {
	cache scoreDomain.Cache
}

func NewScoreUseCase(cache scoreDomain.Cache) *ScoreUseCase {
	return &ScoreUseCase{cache: cache}
}

func (uc *ScoreUseCase) SubmitScore(ctx context.Context, userID string, score uint64) error {
	if err := uc.cache.UpdateScore(ctx, userID, score); err != nil {
		return fmt.Errorf("submit score: %w", err)
	}
	return nil
}
