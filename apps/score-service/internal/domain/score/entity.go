package score

import "time"

type Score struct {
	UserID    string
	Value     uint64
	UpdatedAt time.Time
}
