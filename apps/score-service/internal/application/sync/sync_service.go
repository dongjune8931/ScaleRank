package sync

import (
	"context"
	"log"
	"sync"
	"time"

	scoreDomain "github.com/dongjune8931/scalerank/apps/score-service/internal/domain/score"
)

const defaultInterval = 10 * time.Second

type SyncService struct {
	cache    scoreDomain.Cache
	repo     scoreDomain.Repository
	interval time.Duration
	stopCh   chan struct{}
	wg       sync.WaitGroup
}

func NewSyncService(cache scoreDomain.Cache, repo scoreDomain.Repository) *SyncService {
	return &SyncService{
		cache:    cache,
		repo:     repo,
		interval: defaultInterval,
		stopCh:   make(chan struct{}),
	}
}

func (s *SyncService) Start(ctx context.Context) {
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		ticker := time.NewTicker(s.interval)
		defer ticker.Stop()
		for {
			select {
			case <-s.stopCh:
				// do one final sync before exit
				s.sync(ctx)
				return
			case <-ctx.Done():
				return
			case <-ticker.C:
				s.sync(ctx)
			}
		}
	}()
}

func (s *SyncService) Stop() {
	close(s.stopCh)
	s.wg.Wait()
}

func (s *SyncService) sync(ctx context.Context) {
	scores, err := s.cache.PopStagingScores(ctx)
	if err != nil {
		log.Printf("sync: pop staging scores: %v", err)
		return
	}
	if len(scores) == 0 {
		return
	}
	if err := s.repo.BatchUpsertScores(ctx, scores); err != nil {
		log.Printf("sync: batch upsert scores: %v", err)
		return
	}
	log.Printf("sync: synced %d scores to database", len(scores))
}
