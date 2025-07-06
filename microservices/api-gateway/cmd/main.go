package main

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

func main() {
	port := getEnv("PORT", "9750")

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":    "healthy",
			"service":   "api-gateway",
			"timestamp": time.Now().Unix(),
		})
	})

	// Metrics endpoint
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// API routes
	v1 := r.Group("/api/v1")
	{
		v1.GET("/info", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"service": "avalanche-microservices",
				"version": "1.0.0",
				"worker_pools": map[string]string{
					"consensus": "http://consensus-worker-lb:8080",
					"validator": "http://validator-worker-lb:8081",
					"dag_state":  "http://dag-state-worker-lb:8082",
				},
			})
		})
	}

	// Start HTTP server
	server := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	go func() {
		log.Printf("API Gateway starting on port %s", port)
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
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("API Gateway stopped")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
} 