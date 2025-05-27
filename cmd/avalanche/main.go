package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	fmt.Println("Starting Avalanche node with parallel DAG")
	
	// Gunakan versi dummy untuk uji coba Docker
	fmt.Println("Avalanche node with parallel DAG started!")
	fmt.Println("Listening on port 9650...")
	
	// Buat channel untuk menangani signal
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	
	// Tunggu signal untuk keluar
	<-sigs
	fmt.Println("Shutting down...")
} 