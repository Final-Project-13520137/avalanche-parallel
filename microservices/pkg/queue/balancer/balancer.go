package balancer

import (
	"context"
	"encoding/json"

	"github.com/go-redis/redis/v8"
)

// Family mendeskripsikan group antrian untuk suatu stage
type Family struct {
	TaskQueues  []string // high, medium, low
	ResultQueue string
}

// Enqueue menaruh task ke antrean berdasarkan prioritas dan ukuran antrean
func Enqueue(ctx context.Context, rdb *redis.Client, fam Family, task interface{}, priority string) error {
	idx := 1
	switch priority {
	case "high":
		idx = 0
	case "low":
		idx = 2
	}
	best := idx
	bestLen := int64(1<<62 - 1)
	for i, q := range fam.TaskQueues {
		if n, err := rdb.LLen(ctx, q).Result(); err == nil && n < bestLen {
			best = i
			bestLen = n
		}
	}
	data, _ := json.Marshal(task)
	return rdb.LPush(ctx, fam.TaskQueues[best], data).Err()
}
