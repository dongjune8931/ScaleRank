package http

import (
	"net/http"

	"github.com/gin-gonic/gin"

	scoreApp "github.com/dongjune8931/scalerank/apps/score-service/internal/application/score"
)

type ScoreHandler struct {
	usecase scoreApp.UseCase
}

func NewScoreHandler(usecase scoreApp.UseCase) *ScoreHandler {
	return &ScoreHandler{usecase: usecase}
}

func (h *ScoreHandler) RegisterRoutes(router *gin.Engine) {
	router.POST("/api/scores", h.SubmitScore)
	router.GET("/health", h.Health)
}

func (h *ScoreHandler) SubmitScore(c *gin.Context) {
	var req SubmitScoreRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.UserID == "" || len(req.UserID) > 100 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid userId"})
		return
	}

	if err := h.usecase.SubmitScore(c.Request.Context(), req.UserID, req.Score); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, SubmitScoreResponse{
		UserID: req.UserID,
		Score:  req.Score,
	})
}

func (h *ScoreHandler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
