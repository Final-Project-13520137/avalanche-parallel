package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// Transaction represents a blockchain transaction
type Transaction struct {
	ID        string                 `json:"id"`
	From      string                 `json:"from"`
	To        string                 `json:"to"`
	Amount    float64                `json:"amount"`
	Fee       float64                `json:"fee"`
	Timestamp time.Time              `json:"timestamp"`
	Data      map[string]interface{} `json:"data"`
	Signature string                 `json:"signature"`
}

// Block represents a blockchain block
type Block struct {
	Index        uint64            `json:"index"`
	Timestamp    time.Time         `json:"timestamp"`
	Transactions []Transaction     `json:"transactions"`
	PrevHash     string            `json:"prev_hash"`
	Hash         string            `json:"hash"`
}

// Status represents the blockchain status
type Status struct {
	ChainHeight     int    `json:"chain_height"`
	PendingTxs      int    `json:"pending_txs"`
	ConsensusMode   string `json:"consensus_mode"`
	NetworkMode     string `json:"network_mode"`
	PeerCount       int    `json:"peer_count"`
	LatestBlockHash string `json:"latest_block_hash"`
}

func main() {
	// Base URL of the blockchain API
	baseURL := "http://localhost:9650"

	// Check health
	fmt.Println("1. Checking blockchain health...")
	checkHealth(baseURL)

	// Get status
	fmt.Println("\n2. Getting blockchain status...")
	getStatus(baseURL)

	// Submit transactions
	fmt.Println("\n3. Submitting transactions...")
	for i := 1; i <= 5; i++ {
		tx := Transaction{
			ID:        fmt.Sprintf("tx-%d-%d", time.Now().Unix(), i),
			From:      fmt.Sprintf("address%d", i),
			To:        fmt.Sprintf("address%d", i+1),
			Amount:    float64(i * 100),
			Fee:       0.1,
			Timestamp: time.Now(),
			Data: map[string]interface{}{
				"memo": fmt.Sprintf("Transaction %d", i),
			},
			Signature: "dummy-signature",
		}
		submitTransaction(baseURL, tx)
		time.Sleep(1 * time.Second)
	}

	// Wait for block production
	fmt.Println("\n4. Waiting for block production...")
	time.Sleep(15 * time.Second)

	// Get blocks
	fmt.Println("\n5. Getting blocks...")
	getBlocks(baseURL)

	// Get specific block
	fmt.Println("\n6. Getting specific block (index 0)...")
	getBlock(baseURL, 0)

	// Monitor status
	fmt.Println("\n7. Monitoring blockchain status...")
	monitorStatus(baseURL, 5)
}

func checkHealth(baseURL string) {
	resp, err := http.Get(baseURL + "/health")
	if err != nil {
		log.Printf("Error checking health: %v", err)
		return
	}
	defer resp.Body.Close()

	var result map[string]string
	json.NewDecoder(resp.Body).Decode(&result)
	fmt.Printf("Health: %s\n", result["status"])
}

func getStatus(baseURL string) {
	resp, err := http.Get(baseURL + "/status")
	if err != nil {
		log.Printf("Error getting status: %v", err)
		return
	}
	defer resp.Body.Close()

	var status Status
	json.NewDecoder(resp.Body).Decode(&status)
	fmt.Printf("Status: %+v\n", status)
}

func submitTransaction(baseURL string, tx Transaction) {
	data, err := json.Marshal(tx)
	if err != nil {
		log.Printf("Error marshaling transaction: %v", err)
		return
	}

	resp, err := http.Post(baseURL+"/transactions", "application/json", bytes.NewBuffer(data))
	if err != nil {
		log.Printf("Error submitting transaction: %v", err)
		return
	}
	defer resp.Body.Close()

	var result map[string]string
	json.NewDecoder(resp.Body).Decode(&result)
	fmt.Printf("Transaction submitted: %s - %s\n", tx.ID, result["status"])
}

func getBlocks(baseURL string) {
	resp, err := http.Get(baseURL + "/blocks")
	if err != nil {
		log.Printf("Error getting blocks: %v", err)
		return
	}
	defer resp.Body.Close()

	var blocks []Block
	json.NewDecoder(resp.Body).Decode(&blocks)
	fmt.Printf("Total blocks: %d\n", len(blocks))
	for _, block := range blocks {
		fmt.Printf("  Block %d: %s (txs: %d)\n", block.Index, block.Hash[:16]+"...", len(block.Transactions))
	}
}

func getBlock(baseURL string, index uint64) {
	resp, err := http.Get(fmt.Sprintf("%s/blocks/%d", baseURL, index))
	if err != nil {
		log.Printf("Error getting block: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		fmt.Printf("Block %d not found\n", index)
		return
	}

	var block Block
	json.NewDecoder(resp.Body).Decode(&block)
	fmt.Printf("Block %d:\n", block.Index)
	fmt.Printf("  Hash: %s\n", block.Hash)
	fmt.Printf("  Previous Hash: %s\n", block.PrevHash)
	fmt.Printf("  Timestamp: %s\n", block.Timestamp.Format(time.RFC3339))
	fmt.Printf("  Transactions: %d\n", len(block.Transactions))
}

func monitorStatus(baseURL string, duration int) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	timeout := time.After(time.Duration(duration) * time.Second)
	
	for {
		select {
		case <-timeout:
			fmt.Println("Monitoring complete")
			return
		case <-ticker.C:
			resp, err := http.Get(baseURL + "/status")
			if err != nil {
				log.Printf("Error getting status: %v", err)
				continue
			}
			
			var status Status
			json.NewDecoder(resp.Body).Decode(&status)
			resp.Body.Close()
			
			fmt.Printf("[%s] Height: %d, Pending: %d, Peers: %d\n",
				time.Now().Format("15:04:05"),
				status.ChainHeight,
				status.PendingTxs,
				status.PeerCount)
		}
	}
} 