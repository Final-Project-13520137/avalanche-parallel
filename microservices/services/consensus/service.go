package consensus

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// ConsensusService represents the HTTP service wrapper
type ConsensusService struct {
	engine Engine
}

// NewConsensusService creates a new consensus HTTP service
func NewConsensusService() (*ConsensusService, error) {
	// Create configuration
	config := Config{
		DBHost:             getEnv("DB_HOST", "localhost"),
		DBPort:             getEnv("DB_PORT", "5432"),
		DBUser:             getEnv("DB_USER", "postgres"),
		DBPassword:         getEnv("DB_PASSWORD", "password"),
		DBName:             getEnv("DB_NAME", "avalanche_state"),
		RedisURL:           getEnv("REDIS_URL", "redis://localhost:6379"),
		ConsensusMode:      getEnv("CONSENSUS_MODE", "snowman"),
		ValidatorThreshold: 0.67,
	}

	// Create consensus engine
	engine, err := NewConsensusEngine(config)
	if err != nil {
		return nil, err
	}

	return &ConsensusService{
		engine: engine,
	}, nil
}

// HTTP Handlers

func (cs *ConsensusService) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func (cs *ConsensusService) readyHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

func (cs *ConsensusService) statusHandler(w http.ResponseWriter, r *http.Request) {
	status, err := cs.engine.GetStatus()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

func (cs *ConsensusService) processBlockHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var block Block
	if err := json.NewDecoder(r.Body).Decode(&block); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid block data"})
		return
	}

	if err := cs.engine.ProcessBlock(&block); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "block processed", "block_id": block.ID})
}

func (cs *ConsensusService) addValidatorHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var validator Validator
	if err := json.NewDecoder(r.Body).Decode(&validator); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid validator data"})
		return
	}

	if err := cs.engine.AddValidator(&validator); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "validator added", "node_id": validator.NodeID})
}

func (cs *ConsensusService) getValidatorsHandler(w http.ResponseWriter, r *http.Request) {
	validators, err := cs.engine.GetValidators()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(validators)
}

// setupRoutes sets up HTTP routes
func (cs *ConsensusService) setupRoutes() *mux.Router {
	router := mux.NewRouter()

	// Health checks
	router.HandleFunc("/health", cs.healthHandler).Methods("GET")
	router.HandleFunc("/ready", cs.readyHandler).Methods("GET")
	router.HandleFunc("/startup", cs.healthHandler).Methods("GET")

	// API endpoints
	router.HandleFunc("/status", cs.statusHandler).Methods("GET")
	router.HandleFunc("/block", cs.processBlockHandler).Methods("POST")
	router.HandleFunc("/validators", cs.addValidatorHandler).Methods("POST")
	router.HandleFunc("/validators", cs.getValidatorsHandler).Methods("GET")

	// Metrics
	router.Handle("/metrics", promhttp.Handler())

	return router
}

// RunService runs the HTTP service
func RunService() {
	log.Println("Starting Consensus Service...")

	// Create consensus service
	service, err := NewConsensusService()
	if err != nil {
		log.Fatalf("Failed to create consensus service: %v", err)
	}

	// Start the engine
	ctx := context.Background()
	if err := service.engine.Start(ctx); err != nil {
		log.Fatalf("Failed to start consensus engine: %v", err)
	}

	// Setup HTTP server
	router := service.setupRoutes()
	server := &http.Server{
		Addr:         ":8080",
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Println("Consensus Service listening on :8080")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Wait for interrupt signal
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c

	log.Println("Shutting down Consensus Service...")

	// Graceful shutdown
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("Server forced to shutdown: %v", err)
	}

	// Stop the engine
	if err := service.engine.Stop(); err != nil {
		log.Printf("Failed to stop consensus engine: %v", err)
	}

	log.Println("Consensus Service stopped")
}

// getEnv gets environment variable with default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
} 