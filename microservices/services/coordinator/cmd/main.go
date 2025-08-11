package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-redis/redis/v8"
)

// Submission mewakili data transaksi yang dikirim dari API Gateway
type Submission struct {
	ID        string                 `json:"id"`
	Priority  string                 `json:"priority"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp time.Time              `json:"timestamp"`
}

// ValidationResult hasil dari validator pool
type ValidationResult struct {
	TaskID string `json:"task_id"`
	Valid  bool   `json:"valid"`
	Reason string `json:"reason"`
}

// ConsensusResult hasil konsensus
type ConsensusResult struct {
	TaskID   string `json:"task_id"`
	Accepted bool   `json:"accepted"`
}

func main() {
	log.Println("Starting Main Coordinator...")

	redisURL := getEnv("REDIS_URL", "redis://redis:6379")
	submissionQueue := getEnv("SUBMISSION_QUEUE", "gateway_submissions")
	resultPrefix := getEnv("RESULT_PREFIX", "submission_results:")

	// Queues family
	validationFamily := queueFamily{
		TaskQueues:   []string{"validation_tasks_high", "validation_tasks_medium", "validation_tasks_low"},
		ResultQueue:  "validation_results",
		DefaultIndex: 1,
	}
	consensusFamily := queueFamily{
		TaskQueues:   []string{"consensus_tasks_high", "consensus_tasks_medium", "consensus_tasks_low"},
		ResultQueue:  "consensus_results",
		DefaultIndex: 1,
	}
	dagFamily := queueFamily{
		TaskQueues:   []string{"dag_tasks_high", "dag_tasks_medium", "dag_tasks_low"},
		ResultQueue:  "dag_state_results",
		DefaultIndex: 1,
	}

	// Redis client
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("failed to parse redis url: %v", err)
	}
	rdb := redis.NewClient(opt)
	ctx := context.Background()
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("failed to connect to redis: %v", err)
	}

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	for {
		select {
		case <-quit:
			log.Println("Coordinator stopping...")
			return
		default:
			// Ambil submission dari gateway
			res := rdb.BRPop(ctx, 5*time.Second, submissionQueue)
			if res.Err() == redis.Nil {
				continue
			}
			if res.Err() != nil || len(res.Val()) < 2 {
				if res.Err() != nil {
					log.Printf("error pop submission: %v", res.Err())
				}
				continue
			}

			var sub Submission
			if err := json.Unmarshal([]byte(res.Val()[1]), &sub); err != nil {
				log.Printf("invalid submission json: %v", err)
				continue
			}

			correlation := sub.ID

			// 1) VALIDATION: kirim 4 tugas paralel (format/signature/balance/transaction)
			validationTasks := []map[string]interface{}{
				{"id": correlation + ":format", "type": "format_validation", "priority": sub.Priority, "timestamp": time.Now(), "transaction": sub.Payload},
				{"id": correlation + ":sig", "type": "signature_verification", "priority": sub.Priority, "timestamp": time.Now(), "transaction": sub.Payload},
				{"id": correlation + ":balance", "type": "balance_check", "priority": sub.Priority, "timestamp": time.Now(), "transaction": sub.Payload},
				{"id": correlation + ":tx", "type": "transaction_validation", "priority": sub.Priority, "timestamp": time.Now(), "transaction": sub.Payload},
			}
			for _, t := range validationTasks {
				balancerEnqueue(ctx, rdb, validationFamily, t, sub.Priority)
			}

			// tunggu 4 hasil
			valid := true
			deadline := time.Now().Add(20 * time.Second)
			for i := 0; i < 4; i++ {
				left := time.Until(deadline)
				if left <= 0 {
					valid = false
					break
				}
				r := rdb.BRPop(ctx, left, validationFamily.ResultQueue)
				if r.Err() != nil || len(r.Val()) < 2 {
					valid = false
					break
				}
				var vr ValidationResult
				_ = json.Unmarshal([]byte(r.Val()[1]), &vr)
				if !vr.Valid {
					valid = false
				}
			}

			if !valid {
				resp := map[string]interface{}{"id": correlation, "status": "rejected", "stage": "validation"}
				buf, _ := json.Marshal(resp)
				rdb.LPush(ctx, resultPrefix+correlation, buf)
				continue
			}

			// 2) CONSENSUS: tugas dengan parameter Avalanche (Snowball)
			consensusTask := map[string]interface{}{
				"id":        correlation,
				"type":      "vertex_validation",
				"priority":  sub.Priority,
				"timestamp": time.Now(),
				"consensus_params": map[string]interface{}{
					"k":             5,
					"alpha":         0.8,
					"beta_virtuous": 5,
					"beta_rogue":    10,
					"max_rounds":    10,
				},
				"transaction": sub.Payload,
			}
			balancerEnqueue(ctx, rdb, consensusFamily, consensusTask, sub.Priority)

			cRes := rdb.BRPop(ctx, 20*time.Second, consensusFamily.ResultQueue)
			if cRes.Err() != nil || len(cRes.Val()) < 2 {
				resp := map[string]interface{}{"id": correlation, "status": "timeout", "stage": "consensus"}
				buf, _ := json.Marshal(resp)
				rdb.LPush(ctx, resultPrefix+correlation, buf)
				continue
			}
			var cr ConsensusResult
			_ = json.Unmarshal([]byte(cRes.Val()[1]), &cr)
			if !cr.Accepted {
				resp := map[string]interface{}{"id": correlation, "status": "rejected", "stage": "consensus"}
				buf, _ := json.Marshal(resp)
				rdb.LPush(ctx, resultPrefix+correlation, buf)
				continue
			}

			// 3) DAG STATE
			dagTask := map[string]interface{}{
				"id":        correlation,
				"type":      "update_dag",
				"priority":  sub.Priority,
				"timestamp": time.Now(),
				"data":      sub.Payload,
			}
			balancerEnqueue(ctx, rdb, dagFamily, dagTask, sub.Priority)

			sRes := rdb.BRPop(ctx, 20*time.Second, dagFamily.ResultQueue)
			if sRes.Err() != nil || len(sRes.Val()) < 2 {
				resp := map[string]interface{}{"id": correlation, "status": "timeout", "stage": "state"}
				buf, _ := json.Marshal(resp)
				rdb.LPush(ctx, resultPrefix+correlation, buf)
				continue
			}

			// Final OK
			resp := map[string]interface{}{"id": correlation, "status": "accepted", "stage": "final"}
			buf, _ := json.Marshal(resp)
			rdb.LPush(ctx, resultPrefix+correlation, buf)
		}
	}
}

type queueFamily struct {
	TaskQueues   []string
	ResultQueue  string
	DefaultIndex int
}

func balancerEnqueue(ctx context.Context, rdb *redis.Client, qf queueFamily, task map[string]interface{}, priority string) {
	// pilih queue berdasarkan priority dan back-pressure simple (LLEN)
	idx := 1 // medium default
	switch priority {
	case "high":
		idx = 0
	case "low":
		idx = 2
	}
	// jika antrean target lebih panjang dari alternatif, pilih yang lebih pendek
	best := idx
	bestLen := int64(1<<62 - 1)
	for i, q := range qf.TaskQueues {
		l, err := rdb.LLen(ctx, q).Result()
		if err == nil && l < bestLen {
			best = i
			bestLen = l
		}
	}
	b, _ := json.Marshal(task)
	_ = rdb.LPush(ctx, qf.TaskQueues[best], b).Err()
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
