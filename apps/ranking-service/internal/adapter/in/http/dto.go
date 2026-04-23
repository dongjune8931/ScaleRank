package http

type RankEntryResponse struct {
	UserID string  `json:"userId"`
	Score  float64 `json:"score"`
	Rank   int64   `json:"rank"`
}

type TopRankingsResponse struct {
	Rankings []RankEntryResponse `json:"rankings"`
	Total    int                 `json:"total"`
}
