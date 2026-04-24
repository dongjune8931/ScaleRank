package score

import "context"

type UseCase interface {
	SubmitScore(ctx context.Context, userID string, score uint64) error
}
