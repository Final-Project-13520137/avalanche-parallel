#!/bin/bash

echo "Downloading missing dependencies for go.sum..."

# Download the specific dependencies needed for Go 1.18
go mod download go.uber.org/atomic@v1.7.0
go mod download go.uber.org/multierr@v1.6.0
go mod download go.uber.org/zap@v1.17.0
go mod download gonum.org/v1/gonum@v0.9.0
go mod download golang.org/x/crypto@v0.0.0-20220112180741-5e0467b6c7ce
go mod download golang.org/x/sys@v0.0.0-20220114195835-da31bd327af9
go mod download

# Run go mod tidy to clean up
go mod tidy

echo "Fixed go.sum entries for Go 1.18 compatibility." 