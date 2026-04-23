package ranking

import (
	"context"

	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
)

const globalLeaderboard = "leaderboard:global"

type RankingUseCase struct {
	cache rankingDomain.Cache
	repo  rankingDomain.Repository
}

func NewRankingUseCase(cache rankingDomain.Cache, repo rankingDomain.Repository) *RankingUseCase {
	return &RankingUseCase{
		cache: cache,
		repo:  repo,
	}
}

func (u *RankingUseCase) GetTopN(ctx context.Context, limit int64) ([]rankingDomain.RankEntry, error) {
	entries, err := u.cache.GetTopN(ctx, globalLeaderboard, limit)
	if err != nil {
		return u.repo.GetTopN(ctx, limit)
	}
	return entries, nil
}

func (u *RankingUseCase) GetUserRank(ctx context.Context, userID string) (*rankingDomain.RankEntry, error) {
	entry, err := u.cache.GetUserRank(ctx, globalLeaderboard, userID)
	if err != nil {
		return u.repo.GetUserRank(ctx, userID)
	}
	return entry, nil
}
