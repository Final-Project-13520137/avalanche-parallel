package main

import (
	"log"

	"github.com/Final-Project-13520137/avalanche-parallel/microservices/api-gateway/internal/server"
)

func main() {
	log.Println("Starting API Gateway...")

	srv := server.NewServer()
	if err := srv.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
