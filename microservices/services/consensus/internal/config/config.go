package config

import (
    "os"
    "strconv"
)

type Config struct {
    Port         int    `json:"port"`
    RedisURL     string `json:"redis_url"`
    DBURL        string `json:"db_url"`
    MetricsPort  int    `json:"metrics_port"`
    LogLevel     string `json:"log_level"`
    
    // Consensus specific config
    NetworkID    uint32 `json:"network_id"`
    SubnetID     string `json:"subnet_id"`
    ChainID      string `json:"chain_id"`
    K            int    `json:"k"`            // Required votes for finalization
    Alpha        int    `json:"alpha"`        // Required votes for preference
    BetaVirtuous int    `json:"beta_virtuous"` // Consecutive successful queries for virtuous txs
    BetaRogue    int    `json:"beta_rogue"`    // Consecutive successful queries for rogue txs
    
    // Performance settings
    MaxOutstandingItems int `json:"max_outstanding_items"`
    BatchSize          int `json:"batch_size"`
}

func Load() (*Config, error) {
    config := &Config{
        Port:        getEnvAsInt("SERVICE_PORT", 9651),
        RedisURL:    getEnv("REDIS_URL", "redis://localhost:6379"),
        DBURL:       getEnv("DB_URL", "postgres://avalanche:avalanche123@localhost:5432/avalanche"),
        MetricsPort: getEnvAsInt("METRICS_PORT", 9751),
        LogLevel:    getEnv("LOG_LEVEL", "info"),
        
        // Consensus parameters (Avalanche defaults)
        NetworkID:    getEnvAsUint32("NETWORK_ID", 1),
        SubnetID:     getEnv("SUBNET_ID", "11111111111111111111111111111111LpoYY"),
        ChainID:      getEnv("CHAIN_ID", "2JVSBoinj9C2J33VntvzYtVJNZdN2NKiwwKjcumHUWEb5DbBrm"),
        K:            getEnvAsInt("K", 20),
        Alpha:        getEnvAsInt("ALPHA", 15),
        BetaVirtuous: getEnvAsInt("BETA_VIRTUOUS", 20),
        BetaRogue:    getEnvAsInt("BETA_ROGUE", 30),
        
        MaxOutstandingItems: getEnvAsInt("MAX_OUTSTANDING_ITEMS", 1000),
        BatchSize:          getEnvAsInt("BATCH_SIZE", 100),
    }
    
    return config, nil
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intValue, err := strconv.Atoi(value); err == nil {
            return intValue
        }
    }
    return defaultValue
}

func getEnvAsUint32(key string, defaultValue uint32) uint32 {
    if value := os.Getenv(key); value != "" {
        if intValue, err := strconv.ParseUint(value, 10, 32); err == nil {
            return uint32(intValue)
        }
    }
    return defaultValue
} 