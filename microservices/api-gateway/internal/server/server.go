package server

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Server struct {
	router *gin.Engine
	port   string
}

func NewServer() *Server {
	port := getEnv("PORT", "9750")

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	return &Server{
		router: r,
		port:   port,
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
				"worker_pools": map[string]string{
					"consensus": "http://consensus-haproxy:8080",
					"validator": "http://validator-haproxy:8081",
					"dag_state": "http://dag-state-haproxy:8082",
				},
			})
		})
	}
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
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
