package ranking

type RankEntry struct {
	UserID string
	Score  float64
	Rank   int64 // 1-based
}
