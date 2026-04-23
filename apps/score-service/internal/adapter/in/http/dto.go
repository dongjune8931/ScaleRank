package http

type SubmitScoreRequest struct {
	UserID string  `json:"userId" binding:"required"`
	Score  float64 `json:"score"  binding:"required"`
}

type SubmitScoreResponse struct {
	UserID string  `json:"userId"`
	Score  float64 `json:"score"`
}
