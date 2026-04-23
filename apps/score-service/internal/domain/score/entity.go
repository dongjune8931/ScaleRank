package score

import "time"

type Score struct {
	UserID    string
	Value     float64
	UpdatedAt time.Time
}
