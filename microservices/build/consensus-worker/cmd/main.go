package main

import (
	"log"

	"github.com/Final-Project-13520137/avalanche-parallel/microservices/workers/consensus-worker/internal/worker"
)

func main() {
	log.Println("Starting Consensus Worker...")

	w := worker.NewWorker()
	if err := w.Start(); err != nil {
		log.Fatalf("Failed to start worker: %v", err)
	}
}
