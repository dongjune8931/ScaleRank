package ranking

type RankEntry struct {
	UserID string
	Score  uint64
	Rank   int64 // 1-based
}
