package ranking

import (
	"context"

	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
)

type UseCase interface {
	GetTopN(ctx context.Context, limit int64) ([]rankingDomain.RankEntry, error)
	GetUserRank(ctx context.Context, userID string) (*rankingDomain.RankEntry, error)
}
