package resilient

import (
	"context"
	"log"
	"sync"
	"sync/atomic"
	"time"

	scoreDomain "github.com/dongjune8931/scalerank/apps/score-service/internal/domain/score"
)

const (
	healthCheckInterval    = 5 * time.Second
	maxConsecutiveFailures = 3
)

type ResilientCache struct {
	primary  scoreDomain.Cache
	fallback scoreDomain.Cache
	healthy  atomic.Bool

	consecutiveFailures int
	mu                  sync.Mutex

	stopCh chan struct{}
	wg     sync.WaitGroup
}

func NewResilientCache(primary, fallback scoreDomain.Cache) *ResilientCache {
	rc := &ResilientCache{
		primary:  primary,
		fallback: fallback,
		stopCh:   make(chan struct{}),
	}
	rc.healthy.Store(true)
	return rc
}

func (r *ResilientCache) Start(ctx context.Context) {
	r.wg.Add(1)
	go func() {
		defer r.wg.Done()
		ticker := time.NewTicker(healthCheckInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-r.stopCh:
				return
			case <-ticker.C:
				r.checkHealth(ctx)
			}
		}
	}()
}

func (r *ResilientCache) Stop() {
	close(r.stopCh)
	r.wg.Wait()
}

func (r *ResilientCache) checkHealth(ctx context.Context) {
	ok := r.primary.IsHealthy(ctx)
	r.mu.Lock()
	defer r.mu.Unlock()

	if ok {
		if !r.healthy.Load() {
			log.Println("resilient cache: primary recovered, switching back")
		}
		r.consecutiveFailures = 0
		r.healthy.Store(true)
	} else {
		r.consecutiveFailures++
		if r.consecutiveFailures >= maxConsecutiveFailures && r.healthy.Load() {
			log.Printf("resilient cache: %d consecutive failures, switching to fallback", r.consecutiveFailures)
			r.healthy.Store(false)
		}
	}
}

func (r *ResilientCache) active() scoreDomain.Cache {
	if r.healthy.Load() {
		return r.primary
	}
	return r.fallback
}

func (r *ResilientCache) UpdateScore(ctx context.Context, userID string, score float64) error {
	return r.active().UpdateScore(ctx, userID, score)
}

func (r *ResilientCache) PopStagingScores(ctx context.Context) (map[string]float64, error) {
	return r.active().PopStagingScores(ctx)
}

func (r *ResilientCache) IsHealthy(ctx context.Context) bool {
	return r.active().IsHealthy(ctx)
}
