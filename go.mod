module github.com/Final-Project-13520137/avalanche-parallel

go 1.21

require (
	github.com/ava-labs/avalanchego v1.10.18
	github.com/google/uuid v1.6.0
	github.com/gorilla/mux v1.8.1
	github.com/stretchr/testify v1.8.4
	github.com/wcharczuk/go-chart/v2 v2.1.2
	go.uber.org/zap v1.26.0
	gopkg.in/natefinch/lumberjack.v2 v2.2.1
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/golang/freetype v0.0.0-20170609003504-e2365dfdc4a0 // indirect
	github.com/google/renameio/v2 v2.0.0 // indirect
	github.com/gorilla/rpc v1.2.1 // indirect
	github.com/mr-tron/base58 v1.2.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	go.uber.org/mock v0.4.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	golang.org/x/crypto v0.23.0 // indirect
	golang.org/x/exp v0.0.0-20231127185646-65229373498e // indirect
	golang.org/x/image v0.18.0 // indirect
	golang.org/x/sys v0.20.0 // indirect
	golang.org/x/term v0.20.0 // indirect
	gonum.org/v1/gonum v0.11.0 // indirect
	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace (
	github.com/Final-Project-13520137/avalanche-parallel/consensus => ./pkg/consensus
	github.com/Final-Project-13520137/avalanche-parallel/pkg/blockchain => ./pkg/blockchain
	github.com/Final-Project-13520137/avalanche-parallel/utils => ./utils
	github.com/Final-Project-13520137/avalanche-parallel/worker => ./pkg/worker
)
