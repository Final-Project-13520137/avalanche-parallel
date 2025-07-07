module benchmark

go 1.21

require (
	github.com/ava-labs/avalanchego v1.10.18
	github.com/go-redis/redis/v8 v8.11.5
	github.com/olekukonko/tablewriter v0.0.5
)

require (
	github.com/btcsuite/btcd v0.23.4 // indirect
	github.com/cespare/xxhash/v2 v2.2.0 // indirect
	github.com/decred/dcrd/dcrec/secp256k1/v3 v3.0.0 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/gorilla/rpc v1.2.1 // indirect
	github.com/mattn/go-runewidth v0.0.9 // indirect
	github.com/prometheus/client_golang v1.17.0 // indirect
	github.com/prometheus/client_model v0.5.0 // indirect
	github.com/syndtr/goleveldb v1.0.1-0.20220721030215-126854af5e6d // indirect
	go.uber.org/zap v1.26.0 // indirect
	golang.org/x/crypto v0.16.0 // indirect
	golang.org/x/term v0.15.0 // indirect
	gonum.org/v1/gonum v0.14.0 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.2.1 // indirect
)

replace benchmark/types => ./types
