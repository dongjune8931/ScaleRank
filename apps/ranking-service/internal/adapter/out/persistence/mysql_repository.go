package persistence

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	rankingDomain "github.com/dongjune8931/scalerank/apps/ranking-service/internal/domain/ranking"
)

type scoreRecord struct {
	UserID    string    `gorm:"primaryKey;column:user_id"`
	Score     uint64    `gorm:"column:score;type:bigint unsigned"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime"`
}

func (scoreRecord) TableName() string { return "scores" }

type MySQLRepository struct {
	db *gorm.DB
}

func NewMySQLRepository(db *gorm.DB) *MySQLRepository {
	return &MySQLRepository{db: db}
}

func (r *MySQLRepository) GetTopN(ctx context.Context, n int64) ([]rankingDomain.RankEntry, error) {
	if n <= 0 {
		n = 100
	}
	if n > 1000 {
		n = 1000
	}
	var records []scoreRecord
	result := r.db.WithContext(ctx).
		Select("user_id, score").
		Order("score DESC").
		Limit(int(n)).
		Find(&records)

	if result.Error != nil {
		return nil, fmt.Errorf("get top N from db: %w", result.Error)
	}

	entries := make([]rankingDomain.RankEntry, 0, len(records))
	for i, rec := range records {
		entries = append(entries, rankingDomain.RankEntry{
			UserID: rec.UserID,
			Score:  rec.Score,
			Rank:   int64(i) + 1,
		})
	}
	return entries, nil
}

func (r *MySQLRepository) GetUserRank(ctx context.Context, userID string) (*rankingDomain.RankEntry, error) {
	var result *rankingDomain.RankEntry

	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var rec scoreRecord
		if err := tx.Where("user_id = ?", userID).First(&rec).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil // result stays nil
			}
			return fmt.Errorf("find user score: %w", err)
		}

		var rank int64
		if err := tx.Model(&scoreRecord{}).
			Where("score > ?", rec.Score).
			Count(&rank).Error; err != nil {
			return fmt.Errorf("count higher scores: %w", err)
		}

		result = &rankingDomain.RankEntry{
			UserID: rec.UserID,
			Score:  rec.Score,
			Rank:   rank + 1,
		}
		return nil
	})

	if err != nil {
		return nil, err
	}
	return result, nil
}
