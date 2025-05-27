// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	fmt.Println("Starting Avalanche DAG worker service")
	
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"healthy"}`))
	})
	
	http.HandleFunc("/tasks", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"accepted","task_id":"placeholder"}`))
	})
	
	port := os.Getenv("PORT")
	if port == "" {
		port = "9652"
	}
	
	fmt.Printf("Worker service listening on port %s\n", port)
	http.ListenAndServe(":"+port, nil)
} 