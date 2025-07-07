package main

import "errors"

var (
	// ErrUTXONotFound is returned when a UTXO is not found or is already spent
	ErrUTXONotFound = errors.New("UTXO not found or already spent")

	// ErrInvalidSignature is returned when transaction signature is invalid
	ErrInvalidSignature = errors.New("invalid transaction signature")

	// ErrInsufficientFunds is returned when account has insufficient funds
	ErrInsufficientFunds = errors.New("insufficient funds")

	// ErrInvalidTransaction is returned when transaction is invalid
	ErrInvalidTransaction = errors.New("invalid transaction")
)
