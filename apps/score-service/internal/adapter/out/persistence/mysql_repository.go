package persistence

import (
	"context"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const batchSize = 500

type scoreRecord struct {
	UserID    string    `gorm:"primaryKey;column:user_id"`
	Score     uint64    `gorm:"column:score;type:bigint unsigned"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime"`
}

func (scoreRecord) TableName() string { return "scores" }

type MySQLRepository struct {
	db *gorm.DB
}

func NewMySQLRepository(db *gorm.DB) *MySQLRepository {
	return &MySQLRepository{db: db}
}

func (r *MySQLRepository) BatchUpsertScores(ctx context.Context, scores map[string]uint64) error {
	records := make([]scoreRecord, 0, len(scores))
	for userID, score := range scores {
		records = append(records, scoreRecord{
			UserID: userID,
			Score:  score,
		})
	}

	for i := 0; i < len(records); i += batchSize {
		end := i + batchSize
		if end > len(records) {
			end = len(records)
		}
		batch := records[i:end]

		result := r.db.WithContext(ctx).
			Clauses(clause.OnConflict{
				Columns:   []clause.Column{{Name: "user_id"}},
				DoUpdates: clause.AssignmentColumns([]string{"score", "updated_at"}),
			}).
			Create(&batch)

		if result.Error != nil {
			return fmt.Errorf("batch upsert scores (chunk %d): %w", i/batchSize, result.Error)
		}
	}
	return nil
}
