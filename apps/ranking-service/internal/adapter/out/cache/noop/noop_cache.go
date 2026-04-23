package noop

import (
	"context"
	"errors"

	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
)

type NoopCache struct{}

func NewNoopCache() *NoopCache {
	return &NoopCache{}
}

func (n *NoopCache) GetTopN(_ context.Context, _ string, _ int64) ([]rankingDomain.RankEntry, error) {
	return nil, errors.New("cache unavailable")
}

func (n *NoopCache) GetUserRank(_ context.Context, _ string, _ string) (*rankingDomain.RankEntry, error) {
	return nil, errors.New("cache unavailable")
}

func (n *NoopCache) IsHealthy(_ context.Context) bool {
	return false
}
