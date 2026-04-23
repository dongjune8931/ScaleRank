package http

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	rankingApp "github.com/dongjune8931/scalerank/apps/ranking-service/internal/application/ranking"
)

const (
	defaultLimit = int64(100)
	maxLimit     = int64(1000)
)

type RankingHandler struct {
	usecase rankingApp.UseCase
}

func NewRankingHandler(usecase rankingApp.UseCase) *RankingHandler {
	return &RankingHandler{usecase: usecase}
}

func (h *RankingHandler) RegisterRoutes(router *gin.Engine) {
	router.GET("/api/rankings/top", h.GetTopN)
	router.GET("/api/rankings/:userId", h.GetUserRank)
	router.GET("/health", h.Health)
}

func (h *RankingHandler) GetTopN(c *gin.Context) {
	limit := defaultLimit

	if raw := c.Query("limit"); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || parsed <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit parameter"})
			return
		}
		if parsed > maxLimit {
			parsed = maxLimit
		}
		limit = parsed
	}

	entries, err := h.usecase.GetTopN(c.Request.Context(), limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rankings := make([]RankEntryResponse, 0, len(entries))
	for _, e := range entries {
		rankings = append(rankings, RankEntryResponse{
			UserID: e.UserID,
			Score:  e.Score,
			Rank:   e.Rank,
		})
	}

	c.JSON(http.StatusOK, TopRankingsResponse{
		Rankings: rankings,
		Total:    len(rankings),
	})
}

func (h *RankingHandler) GetUserRank(c *gin.Context) {
	userID := c.Param("userId")

	entry, err := h.usecase.GetUserRank(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if entry == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}

	c.JSON(http.StatusOK, RankEntryResponse{
		UserID: entry.UserID,
		Score:  entry.Score,
		Rank:   entry.Rank,
	})
}

func (h *RankingHandler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
