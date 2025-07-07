module github.com/Final-Project-13520137/avalanche-parallel/microservices/workers/validator-worker

go 1.21

require (
	github.com/Final-Project-13520137/avalanche-parallel v0.0.0
	github.com/ava-labs/avalanchego v1.10.18
	github.com/go-redis/redis/v8 v8.11.5
	github.com/gorilla/mux v1.8.1
	go.uber.org/zap v1.26.0
)

require (
	github.com/cespare/xxhash/v2 v2.2.0 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	go.uber.org/multierr v1.11.0 // indirect
)

replace github.com/Final-Project-13520137/avalanche-parallel => ../../.. 