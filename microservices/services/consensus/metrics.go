package consensus

import (
	"github.com/prometheus/client_golang/prometheus"
)

// ConsensusMetrics holds Prometheus metrics
type ConsensusMetrics struct {
	BlocksProcessed  prometheus.Counter
	BlocksProduced   prometheus.Counter
	ConsensusLatency prometheus.Histogram
	ValidatorCount   prometheus.Gauge
	BlockHeight      prometheus.Gauge
	ConsensusErrors  prometheus.Counter
}

// NewConsensusMetrics creates new metrics
func NewConsensusMetrics() *ConsensusMetrics {
	return &ConsensusMetrics{
		BlocksProcessed: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "consensus_blocks_processed_total",
			Help: "Total number of blocks processed",
		}),
		BlocksProduced: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "consensus_blocks_produced_total",
			Help: "Total number of blocks produced",
		}),
		ConsensusLatency: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:    "consensus_block_processing_duration_seconds",
			Help:    "Time taken to process blocks",
			Buckets: prometheus.DefBuckets,
		}),
		ValidatorCount: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "consensus_active_validators",
			Help: "Number of active validators",
		}),
		BlockHeight: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "consensus_block_height",
			Help: "Current block height",
		}),
		ConsensusErrors: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "consensus_errors_total",
			Help: "Total number of consensus errors",
		}),
	}
}

// RegisterMetrics registers metrics with Prometheus
func (m *ConsensusMetrics) RegisterMetrics() {
	prometheus.MustRegister(m.BlocksProcessed)
	prometheus.MustRegister(m.BlocksProduced)
	prometheus.MustRegister(m.ConsensusLatency)
	prometheus.MustRegister(m.ValidatorCount)
	prometheus.MustRegister(m.BlockHeight)
	prometheus.MustRegister(m.ConsensusErrors)
} 