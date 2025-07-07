package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	queueDepth = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "worker_queue_depth",
			Help: "Current depth of worker queues",
		},
		[]string{"queue_name"},
	)

	processingTime = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "worker_processing_time_seconds",
			Help:    "Time taken to process tasks",
			Buckets: prometheus.ExponentialBuckets(0.001, 2, 10),
		},
		[]string{"worker_type"},
	)

	errorRate = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_errors_total",
			Help: "Total number of worker errors",
		},
		[]string{"worker_type", "error_type"},
	)
)

func init() {
	prometheus.MustRegister(queueDepth)
	prometheus.MustRegister(processingTime)
	prometheus.MustRegister(errorRate)
}

func main() {
	// Get Redis URL from environment
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		redisURL = "redis://localhost:6379"
	}

	// Connect to Redis
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}

	rdb := redis.NewClient(opt)
	defer rdb.Close()

	// Test Redis connection
	ctx := context.Background()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}

	// Start monitoring goroutine
	go monitorQueues(ctx, rdb)

	// Expose metrics endpoint
	http.Handle("/metrics", promhttp.Handler())
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func monitorQueues(ctx context.Context, rdb *redis.Client) {
	queues := []string{
		"consensus_tasks",
		"validation_tasks",
		"dag_state_tasks",
		"consensus_results",
		"validation_results",
		"dag_state_results",
	}

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			for _, queue := range queues {
				length, err := rdb.LLen(ctx, queue).Result()
				if err != nil {
					log.Printf("Error getting queue length for %s: %v", queue, err)
					errorRate.WithLabelValues("monitor", "redis_error").Inc()
					continue
				}
				queueDepth.WithLabelValues(queue).Set(float64(length))
			}
		}
	}
}
