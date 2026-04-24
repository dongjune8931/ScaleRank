package noop

import "context"

type NoopCache struct{}

func NewNoopCache() *NoopCache {
	return &NoopCache{}
}

func (n *NoopCache) UpdateScore(_ context.Context, _ string, _ uint64) error {
	return nil
}

func (n *NoopCache) PopStagingScores(_ context.Context) (map[string]uint64, error) {
	return map[string]uint64{}, nil
}

func (n *NoopCache) IsHealthy(_ context.Context) bool {
	return false
}
