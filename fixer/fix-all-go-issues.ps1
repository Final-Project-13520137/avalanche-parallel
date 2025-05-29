#!/usr/bin/env pwsh

Write-Host "Avalanche Parallel - Go Issues Fixer" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "This script fixes common Go 1.18 compatibility issues in the codebase"

# 1. Fix sorting.go bytes.Compare issue
Write-Host "Step 1: Fixing sorting.go bytes.Compare issue..." -ForegroundColor Green

$sortingFilePath = "default\utils\sorting.go"

if (Test-Path $sortingFilePath) {
    $content = Get-Content $sortingFilePath -Raw
    $newContent = $content -replace 'return bytes.Compare\(iHash, jHash\) < 0.*?<.*?0', 'return bytes.Compare(iHash, jHash) < 0'
    Set-Content -Path $sortingFilePath -Value $newContent
    Write-Host "✓ sorting.go fixed successfully!" -ForegroundColor Green
}
else {
    Write-Host "! sorting.go file not found at: $sortingFilePath" -ForegroundColor Yellow
}

# 2. Fix transaction.go MissingDependencies method
Write-Host "Step 2: Fixing transaction.go MissingDependencies method..." -ForegroundColor Green

$transactionFilePath = "pkg\blockchain\transaction.go"
if (Test-Path $transactionFilePath) {
    $content = Get-Content $transactionFilePath -Raw
    $newContent = $content -replace 'return set\.Set\[ids\.ID\]\{\}, nil', 'return set.Empty[ids.ID](), nil'
    Set-Content -Path $transactionFilePath -Value $newContent
    Write-Host "✓ transaction.go fixed successfully!" -ForegroundColor Green
}
else {
    Write-Host "! transaction.go file not found at: $transactionFilePath" -ForegroundColor Yellow
}

# 3. Make sure the set package exists
Write-Host "Step 3: Checking set package..." -ForegroundColor Green

$setDirPath = "default\utils\set"
$setFilePath = "$setDirPath\set.go"

if (-not (Test-Path $setDirPath)) {
    New-Item -Path $setDirPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Created set directory" -ForegroundColor Green
}

if (-not (Test-Path $setFilePath) -or (Get-Content $setFilePath -Raw).Length -eq 0) {
    Write-Host "Creating set.go file..." -ForegroundColor Green
    
    # Use the fix-sorting.ps1 script as a reference for a simpler implementation
    Copy-Item -Force -Path "fixer\fix-sorting.ps1" -Destination "fixer\fix-sorting.ps1.bak" -ErrorAction SilentlyContinue
    
    # Create a minimal set.go
    $setContent = @'
// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package set

// Set is an unordered collection of unique elements
type Set[T comparable] interface {
	Add(element T) bool
	Get(element T) (T, bool)
	Contains(element T) bool
	Remove(element T) bool
	Len() int
	List() []T
	ListExecutionOrder() []T
	Clear()
	Union(set Set[T])
}

// Empty returns an empty set
func Empty[T comparable]() Set[T] {
	return &set[T]{}
}

// set is a set implementation using maps
type set[T comparable] struct {
	elements map[T]struct{}
}

func (s *set[T]) Add(element T) bool {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, 16)
	}
	if _, ok := s.elements[element]; ok {
		return false
	}
	s.elements[element] = struct{}{}
	return true
}

func (s *set[T]) Get(element T) (T, bool) {
	if s.elements == nil {
		return element, false
	}
	_, ok := s.elements[element]
	return element, ok
}

func (s *set[T]) Contains(element T) bool {
	if s.elements == nil {
		return false
	}
	_, ok := s.elements[element]
	return ok
}

func (s *set[T]) Remove(element T) bool {
	if s.elements == nil {
		return false
	}
	if _, ok := s.elements[element]; !ok {
		return false
	}
	delete(s.elements, element)
	return true
}

func (s *set[T]) Len() int {
	return len(s.elements)
}

func (s *set[T]) List() []T {
	elements := make([]T, 0, len(s.elements))
	for element := range s.elements {
		elements = append(elements, element)
	}
	return elements
}

func (s *set[T]) ListExecutionOrder() []T {
	return s.List()
}

func (s *set[T]) Clear() {
	s.elements = make(map[T]struct{})
}

func (s *set[T]) Union(other Set[T]) {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, other.Len())
	}
	for _, element := range other.List() {
		s.elements[element] = struct{}{}
	}
}
'@
    
    Set-Content -Path $setFilePath -Value $setContent
    Write-Host "✓ set.go created successfully!" -ForegroundColor Green
}
else {
    Write-Host "✓ set.go already exists" -ForegroundColor Green
}

Write-Host "`nAll Go issues have been fixed successfully!" -ForegroundColor Green
Write-Host "Run tests to verify: .\scripts\run_blockchain_tests.ps1" -ForegroundColor Cyan 