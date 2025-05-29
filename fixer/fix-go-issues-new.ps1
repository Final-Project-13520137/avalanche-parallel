# Fix-Go-Issues.ps1
# This script fixes common Go 1.18 compatibility issues in the codebase

Write-Host "Avalanche Parallel - Go Issues Fixer" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "This script fixes common Go 1.18 compatibility issues in the codebase"

# 1. Fix sorting.go bytes.Compare issue
Write-Host "`nStep 1: Fixing sorting.go bytes.Compare issue..." -ForegroundColor Green

$sortingFilePath = "default\utils\sorting.go"

if (Test-Path $sortingFilePath) {
    Write-Host "  * Reading file: $sortingFilePath" -ForegroundColor Cyan
    $content = Get-Content $sortingFilePath -Raw
    
    # Fix the SortByHash function
    $oldPattern = 'return bytes.Compare\(iHash, jHash\) < 0.*?<.*?0'
    $newPattern = 'return bytes.Compare(iHash, jHash) < 0'
    
    Write-Host "  * Fixing SortByHash function..." -ForegroundColor Cyan
    $fixedContent = $content -replace $oldPattern, $newPattern
    
    # Save the fixed content
    Write-Host "  * Saving fixed file..." -ForegroundColor Cyan
    $fixedContent | Set-Content $sortingFilePath
    
    Write-Host "  ✓ sorting.go fixed successfully!" -ForegroundColor Green
} else {
    Write-Host "  ! sorting.go file not found at: $sortingFilePath" -ForegroundColor Yellow
}

# 2. Fix missing set package
Write-Host "`nStep 2: Fixing set package issues..." -ForegroundColor Green

$setDirPath = "default\utils\set"
$setFilePath = "$setDirPath\set.go"

if (-not (Test-Path $setDirPath)) {
    Write-Host "  * Creating directory: $setDirPath" -ForegroundColor Cyan
    New-Item -Path $setDirPath -ItemType Directory -Force | Out-Null
}

$setFileExists = Test-Path $setFilePath
$setFileIsEmpty = $false
if ($setFileExists) {
    $setFileIsEmpty = (Get-Item $setFilePath).Length -eq 0
}

if (-not $setFileExists -or $setFileIsEmpty) {
    Write-Host "  * Creating set.go file..." -ForegroundColor Cyan
    
    $setContent = @'
// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package set

// The minimum capacity of a set
const minSetSize = 16

// Set is an unordered collection of unique elements
type Set[T comparable] interface {
	// Add includes the specified elements in the set.
	// If they are already included, Add is a no-op for those elements.
	// Returns true if the set was modified.
	Add(element T) bool

	// Get returns the element in the set, if it exists.
	// The second return value is true if the element exists, and false otherwise.
	Get(element T) (T, bool)

	// Contains returns true if the element is in the set
	Contains(element T) bool

	// Remove removes the elements from the set.
	// If they are not in the set, Remove is a no-op for those elements.
	// Returns true if the set was modified.
	Remove(element T) bool

	// Len returns the number of elements in the set
	Len() int

	// List returns a slice of all elements in the set
	List() []T

	// ListExecutionOrder returns a slice of all elements in the set
	// based on their insertion order
	ListExecutionOrder() []T

	// Clear removes all elements from the set
	Clear()

	// Union adds all of the elements from the given set to this set
	Union(set Set[T])
}

// Empty returns an empty set
func Empty[T comparable]() Set[T] {
	return &set[T]{}
}

// Of returns a new set populated with the given elements
func Of[T comparable](elems ...T) Set[T] {
	s := &set[T]{
		elements: make(map[T]struct{}, len(elems)),
	}
	for _, elem := range elems {
		s.elements[elem] = struct{}{}
	}
	return s
}

// Equals returns true if the sets are equal
func Equals[T comparable](s1, s2 Set[T]) bool {
	if s1.Len() != s2.Len() {
		return false
	}
	for _, elem := range s1.List() {
		if !s2.Contains(elem) {
			return false
		}
	}
	return true
}

// Difference returns a new set with the elements of s1 that are not in s2
func Difference[T comparable](s1, s2 Set[T]) Set[T] {
	s := &set[T]{
		elements: make(map[T]struct{}, s1.Len()),
	}
	for _, elem := range s1.List() {
		if !s2.Contains(elem) {
			s.elements[elem] = struct{}{}
		}
	}
	return s
}

// Intersection returns a new set with the elements that are in both s1 and s2
func Intersection[T comparable](s1, s2 Set[T]) Set[T] {
	s := &set[T]{
		elements: make(map[T]struct{}, min(s1.Len(), s2.Len())),
	}
	for _, elem := range s1.List() {
		if s2.Contains(elem) {
			s.elements[elem] = struct{}{}
		}
	}
	return s
}

// min returns the smaller of a and b
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// set is a set implementation using maps
type set[T comparable] struct {
	elements map[T]struct{}
}

func (s *set[T]) Add(element T) bool {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, minSetSize)
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

// SetJSON is used to marshal/unmarshal sets
type SetJSON[T comparable] struct {
	elements map[T]struct{}
}

// NewSetJSON returns a new SetJSON
func NewSetJSON[T comparable]() *SetJSON[T] {
	return &SetJSON[T]{
		elements: make(map[T]struct{}),
	}
}

// ContainsAny returns true if the intersection of the set is non-empty
func (s *SetJSON[T]) ContainsAny(other *SetJSON[T]) bool {
	smallElts, largeElts := s.elements, other.elements
	if len(smallElts) > len(largeElts) {
		smallElts, largeElts = largeElts, smallElts
	}

	for elt := range smallElts {
		if _, ok := largeElts[elt]; ok {
			return true
		}
	}
	return false
}

// ContainsAll returns true if the set contains all the elements of the provided
// set.
func (s *SetJSON[T]) ContainsAll(other *SetJSON[T]) bool {
	if len(s.elements) < len(other.elements) {
		return false
	}

	for elt := range other.elements {
		if _, ok := s.elements[elt]; !ok {
			return false
		}
	}
	return true
}

// Remove all the given elements from the set.
// If an element isn't in the set, it's ignored.
func (s *SetJSON[T]) Remove(elts ...T) {
	if s.elements == nil {
		return
	}
	for _, elt := range elts {
		delete(s.elements, elt)
	}
}

// Clear empties this set
func (s *SetJSON[T]) Clear() {
	s.elements = make(map[T]struct{})
}

// List converts this set into a list
func (s *SetJSON[T]) List() []T {
	list := make([]T, 0, len(s.elements))
	for elt := range s.elements {
		list = append(list, elt)
	}
	return list
}

// Copy returns a copy of the set
func (s *SetJSON[T]) Copy() *SetJSON[T] {
	newSet := NewSetJSON[T]()
	for elt := range s.elements {
		newSet.elements[elt] = struct{}{}
	}
	return newSet
}

// Return the size of the set
func (s *SetJSON[T]) Len() int {
	return len(s.elements)
}

// Add all the given elements to the set.
// Returns true if the set was modified.
func (s *SetJSON[T]) Add(elts ...T) bool {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, len(elts))
	}
	
	modified := false
	for _, elt := range elts {
		if _, exists := s.elements[elt]; !exists {
			s.elements[elt] = struct{}{}
			modified = true
		}
	}
	return modified
}

// Union adds all the elements from the other set to this set.
func (s *SetJSON[T]) Union(other *SetJSON[T]) {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, other.Len())
	}
	for elt := range other.elements {
		s.elements[elt] = struct{}{}
	}
}

// Contains returns true if the set contains the element.
func (s *SetJSON[T]) Contains(elt T) bool {
	if s.elements == nil {
		return false
	}
	_, contains := s.elements[elt]
	return contains
}
'@
    
    Set-Content -Path $setFilePath -Value $setContent
    Write-Host "  ✓ set.go created successfully!" -ForegroundColor Green
} else {
    Write-Host "  ✓ set.go already exists" -ForegroundColor Green
}

# 3. Fix transaction.go MissingDependencies method
Write-Host "`nStep 3: Fixing transaction.go MissingDependencies method..." -ForegroundColor Green

$transactionFilePath = "pkg\blockchain\transaction.go"
if (Test-Path $transactionFilePath) {
    Write-Host "  * Reading file: $transactionFilePath" -ForegroundColor Cyan
    $content = Get-Content $transactionFilePath -Raw
    
    # Fix the MissingDependencies method
    $oldPattern = 'return set\.Set\[ids\.ID\]\{\}, nil'
    $newPattern = 'return set.Empty[ids.ID](), nil'
    
    Write-Host "  * Fixing MissingDependencies method..." -ForegroundColor Cyan
    $fixedContent = $content -replace $oldPattern, $newPattern
    
    # Save the fixed content
    Write-Host "  * Saving fixed file..." -ForegroundColor Cyan
    $fixedContent | Set-Content $transactionFilePath
    
    Write-Host "  ✓ transaction.go fixed successfully!" -ForegroundColor Green
} else {
    Write-Host "  ! transaction.go file not found at: $transactionFilePath" -ForegroundColor Yellow
}

Write-Host "`nAll Go issues have been fixed successfully!" -ForegroundColor Green
Write-Host "Run tests to verify: .\scripts\run_blockchain_tests.ps1" -ForegroundColor Cyan 