package server

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Server struct {
	router *gin.Engine
	port   string

	redis *redis.Client
}

func NewServer() *Server {
	port := getEnv("PORT", "9750")

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// Redis client
	redisURL := getEnv("REDIS_URL", "redis://redis:6379")
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("invalid redis url: %v", err)
	}
	rdb := redis.NewClient(opt)

	return &Server{
		router: r,
		port:   port,
		redis:  rdb,
	}
}

func (s *Server) setupRoutes() {
	// Health check endpoint
	s.router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":    "healthy",
			"service":   "api-gateway",
			"timestamp": time.Now().Unix(),
		})
	})

	// Metrics endpoint
	s.router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// API routes
	v1 := s.router.Group("/api/v1")
	{
		v1.GET("/info", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"service": "avalanche-microservices",
				"version": "1.0.0",
			})
		})

		// Submit transaction -> kirim ke coordinator via Redis submission queue
		v1.POST("/tx/submit", s.handleSubmit)
	}
}

// handleSubmit menerima transaksi, melakukan pre-check ringan, lalu dorong ke antrean submission
func (s *Server) handleSubmit(c *gin.Context) {
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}

	// Basic rate limit (simple token bucket per IP bisa ditambahkan; sekarang timestamp check)
	priority := "medium"
	if p, ok := payload["priority"].(string); ok {
		priority = p
	}
	id := time.Now().Format("20060102T150405.000000000")

	sub := map[string]interface{}{
		"id":        id,
		"priority":  priority,
		"payload":   payload,
		"timestamp": time.Now(),
	}
	data, _ := json.Marshal(sub)

	ctx := context.Background()
	if err := s.redis.LPush(ctx, "gateway_submissions", data).Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to enqueue"})
		return
	}

	// Tunggu result singkat (long polling) dari coordinator
	resKey := "submission_results:" + id
	res := s.redis.BRPop(ctx, 25*time.Second, resKey)
	if res.Err() != nil || len(res.Val()) < 2 {
		c.JSON(http.StatusAccepted, gin.H{"status": "queued", "id": id})
		return
	}
	var out map[string]interface{}
	_ = json.Unmarshal([]byte(res.Val()[1]), &out)
	c.JSON(http.StatusOK, out)
}

func (s *Server) Start() error {
	s.setupRoutes()

	server := &http.Server{
		Addr:    ":" + s.port,
		Handler: s.router,
	}

	// Start server in goroutine
	go func() {
		log.Printf("API Gateway starting on port %s", s.port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server:", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down API Gateway...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		return err
	}

	log.Println("API Gateway stopped")
	return nil
}

func getEnv(key, defaultValue string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultValue
}
