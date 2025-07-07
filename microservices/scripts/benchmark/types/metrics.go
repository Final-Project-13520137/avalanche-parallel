package types

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"
)

// GetWorkerPoolMetrics mengambil metrik dari semua worker
func (ab *AvalancheBenchmark) GetWorkerPoolMetrics() (*WorkerPoolMetrics, error) {
	metrics := &WorkerPoolMetrics{
		Workers:   make([]WorkerMetrics, 0),
		Timestamp: time.Now(),
	}

	// Mengambil metrik dari validator workers
	validatorMetrics, err := ab.getWorkerMetrics(ab.Config.MicroservicesConfig.ValidatorEndpoint + "/metrics")
	if err != nil {
		return nil, fmt.Errorf("failed to get validator metrics: %v", err)
	}
	metrics.Workers = append(metrics.Workers, validatorMetrics...)

	// Mengambil metrik dari consensus workers
	consensusMetrics, err := ab.getWorkerMetrics(ab.Config.MicroservicesConfig.ConsensusEndpoint + "/metrics")
	if err != nil {
		return nil, fmt.Errorf("failed to get consensus metrics: %v", err)
	}
	metrics.Workers = append(metrics.Workers, consensusMetrics...)

	// Mengambil metrik dari DAG state workers
	dagStateMetrics, err := ab.getWorkerMetrics(ab.Config.MicroservicesConfig.DagStateEndpoint + "/metrics")
	if err != nil {
		return nil, fmt.Errorf("failed to get DAG state metrics: %v", err)
	}
	metrics.Workers = append(metrics.Workers, dagStateMetrics...)

	return metrics, nil
}

// GetMonolithMetrics mengambil metrik dari node monolith
func (ab *AvalancheBenchmark) GetMonolithMetrics() (*MonolithMetrics, error) {
	resp, err := http.Get(ab.Config.MonolithEndpoint + "/ext/metrics")
	if err != nil {
		return nil, fmt.Errorf("failed to get monolith metrics: %v", err)
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read metrics response: %v", err)
	}

	var metrics MonolithMetrics
	if err := json.Unmarshal(body, &metrics); err != nil {
		return nil, fmt.Errorf("failed to parse metrics: %v", err)
	}

	metrics.Timestamp = time.Now()
	return &metrics, nil
}

// getWorkerMetrics mengambil metrik dari endpoint worker tertentu
func (ab *AvalancheBenchmark) getWorkerMetrics(endpoint string) ([]WorkerMetrics, error) {
	resp, err := http.Get(endpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to get worker metrics: %v", err)
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read metrics response: %v", err)
	}

	var metrics []WorkerMetrics
	if err := json.Unmarshal(body, &metrics); err != nil {
		return nil, fmt.Errorf("failed to parse metrics: %v", err)
	}

	// Set timestamp for each worker metric
	now := time.Now()
	for i := range metrics {
		metrics[i].Timestamp = now
	}

	return metrics, nil
}
