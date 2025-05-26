package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ava-labs/avalanche-parallel/blockchain/core"
	"github.com/ava-labs/avalanche-parallel/blockchain/consensus"
	"github.com/ava-labs/avalanche-parallel/blockchain/network"
	"github.com/ava-labs/avalanche-parallel/blockchain/storage"
	"github.com/ava-labs/avalanche-parallel/blockchain/types"
	"go.uber.org/zap"
)

var (
	// Command line flags
	consensusMode   = flag.String("consensus", "hybrid", "Consensus mode: microservices, traditional, or hybrid")
	networkMode     = flag.String("network", "mainnet", "Network mode: mainnet, testnet, or local")
	dataDir         = flag.String("datadir", "./data", "Directory for blockchain data")
	apiPort         = flag.Int("apiport", 9650, "Port for API server")
	p2pPort         = flag.Int("p2pport", 9651, "Port for P2P networking")
	bootstrapNodes  = flag.String("bootstrap", "", "Comma-separated list of bootstrap nodes")
	validatorKey    = flag.String("validator-key", "", "Path to validator private key")
	validatorCert   = flag.String("validator-cert", "", "Path to validator certificate")
	microserviceURL = flag.String("microservice-url", "http://localhost:8080", "URL for microservices consensus")
)

func main() {
	flag.Parse()

	// Initialize logger
	logger, err := zap.NewProduction()
	if err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}
	defer logger.Sync()

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize blockchain configuration
	config := &types.BlockchainConfig{
		ConsensusMode:   *consensusMode,
		NetworkMode:     *networkMode,
		DataDir:         *dataDir,
		APIPort:         *apiPort,
		P2PPort:         *p2pPort,
		BootstrapNodes:  parseBootstrapNodes(*bootstrapNodes),
		ValidatorKey:    *validatorKey,
		ValidatorCert:   *validatorCert,
		MicroserviceURL: *microserviceURL,
	}

	// Initialize storage
	logger.Info("Initializing storage...")
	storageManager, err := storage.NewManager(config.DataDir, logger)
	if err != nil {
		logger.Fatal("Failed to initialize storage", zap.Error(err))
	}
	defer storageManager.Close()

	// Initialize consensus engine based on mode
	logger.Info("Initializing consensus engine", zap.String("mode", config.ConsensusMode))
	consensusEngine, err := initializeConsensus(config, storageManager, logger)
	if err != nil {
		logger.Fatal("Failed to initialize consensus", zap.Error(err))
	}

	// Initialize network layer
	logger.Info("Initializing network layer...")
	networkManager, err := network.NewManager(config, consensusEngine, logger)
	if err != nil {
		logger.Fatal("Failed to initialize network", zap.Error(err))
	}

	// Create blockchain instance
	logger.Info("Creating blockchain instance...")
	blockchain, err := core.NewBlockchain(config, storageManager, consensusEngine, networkManager, logger)
	if err != nil {
		logger.Fatal("Failed to create blockchain", zap.Error(err))
	}

	// Start blockchain
	logger.Info("Starting blockchain...")
	if err := blockchain.Start(ctx); err != nil {
		logger.Fatal("Failed to start blockchain", zap.Error(err))
	}

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	logger.Info("Blockchain is running", 
		zap.String("consensus", config.ConsensusMode),
		zap.String("network", config.NetworkMode),
		zap.Int("api_port", config.APIPort),
		zap.Int("p2p_port", config.P2PPort))

	// Wait for shutdown signal
	<-sigChan
	logger.Info("Shutdown signal received, stopping blockchain...")

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := blockchain.Stop(shutdownCtx); err != nil {
		logger.Error("Error during shutdown", zap.Error(err))
	}

	logger.Info("Blockchain stopped successfully")
}

func initializeConsensus(config *types.BlockchainConfig, storage storage.Manager, logger *zap.Logger) (consensus.Engine, error) {
	switch config.ConsensusMode {
	case "microservices":
		// Use microservices-based consensus wrapper
		return consensus.NewMicroservicesWrapper(config.MicroserviceURL, storage, logger)
	case "traditional":
		// Use traditional Avalanche consensus wrapper
		return consensus.NewTraditionalWrapper(storage, logger)
	case "hybrid":
		// Use hybrid approach combining both
		microservices, err := consensus.NewMicroservicesWrapper(config.MicroserviceURL, storage, logger)
		if err != nil {
			logger.Warn("Failed to create microservices consensus, using traditional only", zap.Error(err))
			return consensus.NewTraditionalWrapper(storage, logger)
		}
		
		traditional, err := consensus.NewTraditionalWrapper(storage, logger)
		if err != nil {
			return nil, fmt.Errorf("failed to create traditional consensus: %w", err)
		}
		
		return consensus.NewHybridConsensus(microservices, traditional, storage, logger)
	default:
		return nil, fmt.Errorf("unknown consensus mode: %s", config.ConsensusMode)
	}
}

func parseBootstrapNodes(nodes string) []string {
	if nodes == "" {
		return []string{}
	}
	// Parse comma-separated bootstrap nodes
	var result []string
	for _, node := range splitAndTrim(nodes, ",") {
		if node != "" {
			result = append(result, node)
		}
	}
	return result
}

func splitAndTrim(s string, sep string) []string {
	if s == "" {
		return []string{}
	}
	parts := make([]string, 0)
	for _, part := range split(s, sep) {
		if trimmed := trim(part); trimmed != "" {
			parts = append(parts, trimmed)
		}
	}
	return parts
}

func split(s string, sep string) []string {
	if s == "" {
		return []string{}
	}
	return stringsSplit(s, sep)
}

func trim(s string) string {
	return stringsTrim(s, " \t\n\r")
}

// Helper functions to avoid importing strings package
func stringsSplit(s, sep string) []string {
	if s == "" {
		return []string{}
	}
	n := 1
	for i := 0; i < len(s); i++ {
		if i+len(sep) <= len(s) && s[i:i+len(sep)] == sep {
			n++
		}
	}
	result := make([]string, n)
	na := 0
	p := 0
	for i := 0; i < len(s); i++ {
		if i+len(sep) <= len(s) && s[i:i+len(sep)] == sep {
			result[na] = s[p:i]
			na++
			p = i + len(sep)
			i = p - 1
		}
	}
	result[na] = s[p:]
	return result
}

func stringsTrim(s string, cutset string) string {
	if s == "" {
		return s
	}
	// Trim leading
	start := 0
	for start < len(s) {
		found := false
		for _, c := range cutset {
			if rune(s[start]) == c {
				found = true
				break
			}
		}
		if !found {
			break
		}
		start++
	}
	// Trim trailing
	end := len(s)
	for end > start {
		found := false
		for _, c := range cutset {
			if rune(s[end-1]) == c {
				found = true
				break
			}
		}
		if !found {
			break
		}
		end--
	}
	return s[start:end]
} 