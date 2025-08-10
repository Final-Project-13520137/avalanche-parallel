// Copyright (C) 2024, Avalanche Parallel Processing. All rights reserved.
// App interface compatibility layer

package app

// FlowManager adalah alias interface untuk kompatibilitas
type FlowManager interface {
	Initialize() error
	Shutdown() error
	GetSystemStatus() map[string]interface{}
}

// Ensure AvalancheMonolithicFlow implements FlowManager
var _ FlowManager = (*AvalancheMonolithicFlow)(nil)
