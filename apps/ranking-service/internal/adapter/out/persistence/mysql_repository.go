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
	var rec scoreRecord
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&rec).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("get user score from db: %w", err)
	}

	var rank int64
	subQuery := r.db.WithContext(ctx).Model(&scoreRecord{}).Select("score").Where("user_id = ?", userID)
	if err := r.db.WithContext(ctx).Model(&scoreRecord{}).
		Where("score > (?)", subQuery).
		Count(&rank).Error; err != nil {
		return nil, fmt.Errorf("count higher scores from db: %w", err)
	}

	return &rankingDomain.RankEntry{
		UserID: rec.UserID,
		Score:  rec.Score,
		Rank:   rank + 1,
	}, nil
}
