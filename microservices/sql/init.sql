-- Avalanche Microservices Database Initialization
-- Create necessary tables for worker pools

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS avalanche;
CREATE SCHEMA IF NOT EXISTS consensus;
CREATE SCHEMA IF NOT EXISTS validation;
CREATE SCHEMA IF NOT EXISTS dag_state;

-- Set search path
SET search_path TO avalanche, public;

-- Consensus tables
CREATE TABLE IF NOT EXISTS consensus.vertices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vertex_id VARCHAR(255) UNIQUE NOT NULL,
    parent_ids TEXT[],
    height BIGINT NOT NULL DEFAULT 0,
    transactions JSONB,
    confidence INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(50) NOT NULL DEFAULT 'processing',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS consensus.polls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id VARCHAR(255) UNIQUE NOT NULL,
    vertex_id VARCHAR(255) NOT NULL,
    responses JSONB,
    start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    end_time TIMESTAMP WITH TIME ZONE,
    timeout_seconds INTEGER DEFAULT 10,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);

-- Validation tables
CREATE TABLE IF NOT EXISTS validation.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id VARCHAR(255) UNIQUE NOT NULL,
    data BYTEA,
    hash VARCHAR(255),
    signature BYTEA,
    public_key BYTEA,
    size INTEGER,
    valid BOOLEAN,
    validation_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    validated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS validation.validation_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id VARCHAR(255) NOT NULL,
    worker_id VARCHAR(255) NOT NULL,
    validation_type VARCHAR(100) NOT NULL,
    result BOOLEAN NOT NULL,
    reason TEXT,
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- DAG and State tables
CREATE TABLE IF NOT EXISTS dag_state.dag_vertices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vertex_id VARCHAR(255) UNIQUE NOT NULL,
    parent_ids TEXT[],
    children_ids TEXT[],
    depth INTEGER NOT NULL DEFAULT 0,
    ancestry_path TEXT[],
    confidence_score DECIMAL(3,2) DEFAULT 0.0,
    finalized BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    finalized_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS dag_state.state_updates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vertex_id VARCHAR(255) NOT NULL,
    account_address VARCHAR(255),
    state_changes JSONB,
    previous_state JSONB,
    new_state JSONB,
    applied BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    applied_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS dag_state.snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    snapshot_id VARCHAR(255) UNIQUE NOT NULL,
    vertex_id VARCHAR(255) NOT NULL,
    state_root VARCHAR(255),
    account_states JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Worker metrics and monitoring tables
CREATE TABLE IF NOT EXISTS avalanche.worker_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id VARCHAR(255) NOT NULL,
    worker_type VARCHAR(100) NOT NULL,
    processed_tasks INTEGER DEFAULT 0,
    successful_tasks INTEGER DEFAULT 0,
    failed_tasks INTEGER DEFAULT 0,
    average_processing_time_ms DECIMAL(10,2),
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS avalanche.task_queue_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    queue_name VARCHAR(255) NOT NULL,
    depth INTEGER DEFAULT 0,
    processed_rate DECIMAL(10,2),
    average_wait_time_ms DECIMAL(10,2),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_vertices_vertex_id ON consensus.vertices(vertex_id);
CREATE INDEX IF NOT EXISTS idx_vertices_status ON consensus.vertices(status);
CREATE INDEX IF NOT EXISTS idx_vertices_created_at ON consensus.vertices(created_at);

CREATE INDEX IF NOT EXISTS idx_transactions_transaction_id ON validation.transactions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transactions_valid ON validation.transactions(valid);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON validation.transactions(created_at);

CREATE INDEX IF NOT EXISTS idx_dag_vertices_vertex_id ON dag_state.dag_vertices(vertex_id);
CREATE INDEX IF NOT EXISTS idx_dag_vertices_finalized ON dag_state.dag_vertices(finalized);
CREATE INDEX IF NOT EXISTS idx_dag_vertices_depth ON dag_state.dag_vertices(depth);

CREATE INDEX IF NOT EXISTS idx_worker_metrics_worker_id ON avalanche.worker_metrics(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_metrics_type ON avalanche.worker_metrics(worker_type);
CREATE INDEX IF NOT EXISTS idx_worker_metrics_last_activity ON avalanche.worker_metrics(last_activity);

-- Create functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_vertices_updated_at BEFORE UPDATE ON consensus.vertices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert initial data
INSERT INTO avalanche.worker_metrics (worker_id, worker_type, processed_tasks, successful_tasks, failed_tasks)
VALUES 
    ('consensus-worker-1', 'consensus', 0, 0, 0),
    ('consensus-worker-2', 'consensus', 0, 0, 0),
    ('consensus-worker-3', 'consensus', 0, 0, 0),
    ('validator-worker-1', 'validator', 0, 0, 0),
    ('validator-worker-2', 'validator', 0, 0, 0),
    ('validator-worker-3', 'validator', 0, 0, 0),
    ('validator-worker-4', 'validator', 0, 0, 0),
    ('validator-worker-5', 'validator', 0, 0, 0),
    ('dag-state-worker-1', 'dag-state', 0, 0, 0),
    ('dag-state-worker-2', 'dag-state', 0, 0, 0)
ON CONFLICT (worker_id) DO NOTHING;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA avalanche TO avalanche;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA consensus TO avalanche;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA validation TO avalanche;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dag_state TO avalanche;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA avalanche TO avalanche;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA consensus TO avalanche;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA validation TO avalanche;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA dag_state TO avalanche; 