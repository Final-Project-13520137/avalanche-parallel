package server

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "sync"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/ava-labs/avalanchego/ids"
    "github.com/ava-labs/avalanchego/snow/choices"
    "avalanche-microservices/services/consensus/internal/config"
    "avalanche-microservices/shared/common"
)

// ConsensusEngine implements the Avalanche consensus protocol
type ConsensusEngine struct {
    config    *config.Config
    vertices  map[ids.ID]*VertexState
    polls     map[ids.ID]*Poll
    mutex     sync.RWMutex
    startTime time.Time
}

// VertexState tracks the state of a vertex in consensus
type VertexState struct {
    Vertex     *common.Vertex  `json:"vertex"`
    Status     choices.Status  `json:"status"`
    Confidence int            `json:"confidence"`
    Polls      map[ids.ID]*Poll `json:"polls"`
    LastUpdate time.Time      `json:"last_update"`
}

// Poll represents a consensus poll for a vertex
type Poll struct {
    ID         ids.ID      `json:"id"`
    VertexID   ids.ID      `json:"vertex_id"`
    Responses  map[ids.ID]choices.Status `json:"responses"`
    StartTime  time.Time   `json:"start_time"`
    Timeout    time.Duration `json:"timeout"`
}

type Server struct {
    config    *config.Config
    engine    *ConsensusEngine
    httpServer *http.Server
}

func New(cfg *config.Config) (*Server, error) {
    engine := &ConsensusEngine{
        config:    cfg,
        vertices:  make(map[ids.ID]*VertexState),
        polls:     make(map[ids.ID]*Poll),
        startTime: time.Now(),
    }
    
    return &Server{
        config: cfg,
        engine: engine,
    }, nil
}

func (s *Server) Start(ctx context.Context) error {
    router := s.setupRoutes()
    
    s.httpServer = &http.Server{
        Addr:         fmt.Sprintf(":%d", s.config.Port),
        Handler:      router,
        ReadTimeout:  30 * time.Second,
        WriteTimeout: 30 * time.Second,
        IdleTimeout:  120 * time.Second,
    }
    
    fmt.Printf("Starting Consensus Service on port %d\n", s.config.Port)
    return s.httpServer.ListenAndServe()
}

func (s *Server) Stop(ctx context.Context) error {
    if s.httpServer != nil {
        return s.httpServer.Shutdown(ctx)
    }
    return nil
}

func (s *Server) setupRoutes() *mux.Router {
    router := mux.NewRouter()
    
    // Health check
    router.HandleFunc("/health", s.handleHealth).Methods("GET")
    
    // Metrics
    router.HandleFunc("/metrics", s.handleMetrics).Methods("GET")
    
    // Consensus API endpoints
    api := router.PathPrefix("/consensus").Subrouter()
    api.HandleFunc("/vertex", s.handleAddVertex).Methods("POST")
    api.HandleFunc("/vertex/{id}", s.handleGetVertex).Methods("GET")
    api.HandleFunc("/poll", s.handlePoll).Methods("POST")
    api.HandleFunc("/query", s.handleQuery).Methods("POST")
    api.HandleFunc("/status", s.handleStatus).Methods("GET")
    
    return router
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
    health := common.HealthStatus{
        Service:   "consensus",
        Status:    "healthy",
        Uptime:    time.Since(s.engine.startTime),
        Version:   "1.0.0",
        Timestamp: time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(health)
}

func (s *Server) handleMetrics(w http.ResponseWriter, r *http.Request) {
    s.engine.mutex.RLock()
    defer s.engine.mutex.RUnlock()
    
    metrics := map[string]interface{}{
        "vertices_total":      len(s.engine.vertices),
        "active_polls":        len(s.engine.polls),
        "finalized_vertices":  s.countVerticesByStatus(choices.Accepted),
        "rejected_vertices":   s.countVerticesByStatus(choices.Rejected),
        "processing_vertices": s.countVerticesByStatus(choices.Processing),
        "uptime_seconds":      time.Since(s.engine.startTime).Seconds(),
        "timestamp":          time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(metrics)
}

func (s *Server) handleAddVertex(w http.ResponseWriter, r *http.Request) {
    var vertex common.Vertex
    if err := json.NewDecoder(r.Body).Decode(&vertex); err != nil {
        http.Error(w, "Invalid vertex data", http.StatusBadRequest)
        return
    }
    
    // Add vertex to consensus
    state := &VertexState{
        Vertex:     &vertex,
        Status:     choices.Processing,
        Confidence: 0,
        Polls:      make(map[ids.ID]*Poll),
        LastUpdate: time.Now(),
    }
    
    s.engine.mutex.Lock()
    s.engine.vertices[vertex.ID] = state
    s.engine.mutex.Unlock()
    
    // Start consensus polling for this vertex
    go s.startConsensusPoll(&vertex)
    
    response := common.ServiceResponse{
        Success:   true,
        Data:      map[string]interface{}{"vertex_id": vertex.ID.String()},
        Timestamp: time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (s *Server) handleGetVertex(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    vertexIDStr := vars["id"]
    
    vertexID, err := ids.FromString(vertexIDStr)
    if err != nil {
        http.Error(w, "Invalid vertex ID", http.StatusBadRequest)
        return
    }
    
    s.engine.mutex.RLock()
    state, exists := s.engine.vertices[vertexID]
    s.engine.mutex.RUnlock()
    
    if !exists {
        http.Error(w, "Vertex not found", http.StatusNotFound)
        return
    }
    
    response := common.ServiceResponse{
        Success:   true,
        Data:      state,
        Timestamp: time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (s *Server) handlePoll(w http.ResponseWriter, r *http.Request) {
    var pollReq struct {
        VertexID ids.ID           `json:"vertex_id"`
        Votes    map[ids.ID]choices.Status `json:"votes"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&pollReq); err != nil {
        http.Error(w, "Invalid poll data", http.StatusBadRequest)
        return
    }
    
    // Process poll results
    result := s.processPollResults(pollReq.VertexID, pollReq.Votes)
    
    response := common.ServiceResponse{
        Success:   true,
        Data:      result,
        Timestamp: time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (s *Server) handleQuery(w http.ResponseWriter, r *http.Request) {
    var queryReq struct {
        VertexID ids.ID `json:"vertex_id"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&queryReq); err != nil {
        http.Error(w, "Invalid query data", http.StatusBadRequest)
        return
    }
    
    s.engine.mutex.RLock()
    state, exists := s.engine.vertices[queryReq.VertexID]
    s.engine.mutex.RUnlock()
    
    if !exists {
        http.Error(w, "Vertex not found", http.StatusNotFound)
        return
    }
    
    // Return current preference
    preference := s.getPreference(queryReq.VertexID)
    
    response := common.ServiceResponse{
        Success: true,
        Data: map[string]interface{}{
            "vertex_id":  queryReq.VertexID.String(),
            "preference": preference,
            "confidence": state.Confidence,
            "status":     state.Status,
        },
        Timestamp: time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
    s.engine.mutex.RLock()
    defer s.engine.mutex.RUnlock()
    
    status := map[string]interface{}{
        "service":             "consensus",
        "vertices_total":      len(s.engine.vertices),
        "active_polls":        len(s.engine.polls),
        "finalized_vertices":  s.countVerticesByStatus(choices.Accepted),
        "rejected_vertices":   s.countVerticesByStatus(choices.Rejected),
        "processing_vertices": s.countVerticesByStatus(choices.Processing),
        "config": map[string]interface{}{
            "k":             s.config.K,
            "alpha":         s.config.Alpha,
            "beta_virtuous": s.config.BetaVirtuous,
            "beta_rogue":    s.config.BetaRogue,
        },
        "uptime":    time.Since(s.engine.startTime),
        "timestamp": time.Now(),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(status)
}

// Consensus algorithm implementation
func (s *Server) startConsensusPoll(vertex *common.Vertex) {
    pollID := ids.GenerateTestID()
    
    poll := &Poll{
        ID:        pollID,
        VertexID:  vertex.ID,
        Responses: make(map[ids.ID]choices.Status),
        StartTime: time.Now(),
        Timeout:   10 * time.Second,
    }
    
    s.engine.mutex.Lock()
    s.engine.polls[pollID] = poll
    if state, exists := s.engine.vertices[vertex.ID]; exists {
        state.Polls[pollID] = poll
    }
    s.engine.mutex.Unlock()
    
    // Simulate network polling (in real implementation, this would query other nodes)
    go s.simulateNetworkPoll(poll)
}

func (s *Server) simulateNetworkPoll(poll *Poll) {
    // Simulate responses from other nodes
    time.Sleep(100 * time.Millisecond) // Network delay
    
    // Generate simulated responses (in real implementation, query actual nodes)
    responses := make(map[ids.ID]choices.Status)
    for i := 0; i < s.config.K; i++ {
        nodeID := ids.GenerateTestID()
        // Simulate 80% acceptance rate
        if i < int(float64(s.config.K)*0.8) {
            responses[nodeID] = choices.Accepted
        } else {
            responses[nodeID] = choices.Rejected
        }
    }
    
    s.processPollResults(poll.VertexID, responses)
}

func (s *Server) processPollResults(vertexID ids.ID, votes map[ids.ID]choices.Status) map[string]interface{} {
    s.engine.mutex.Lock()
    defer s.engine.mutex.Unlock()
    
    state, exists := s.engine.vertices[vertexID]
    if !exists {
        return map[string]interface{}{"error": "vertex not found"}
    }
    
    // Count votes
    acceptCount := 0
    rejectCount := 0
    
    for _, vote := range votes {
        switch vote {
        case choices.Accepted:
            acceptCount++
        case choices.Rejected:
            rejectCount++
        }
    }
    
    // Apply Avalanche consensus rules
    if acceptCount >= s.config.Alpha {
        state.Confidence++
        
        // Check for finalization
        if state.Confidence >= s.config.BetaVirtuous {
            state.Status = choices.Accepted
        }
    } else if rejectCount >= s.config.Alpha {
        state.Confidence = 0
        
        if rejectCount >= s.config.K {
            state.Status = choices.Rejected
        }
    }
    
    state.LastUpdate = time.Now()
    
    return map[string]interface{}{
        "vertex_id":     vertexID.String(),
        "accept_votes":  acceptCount,
        "reject_votes":  rejectCount,
        "confidence":    state.Confidence,
        "status":        state.Status,
        "finalized":     state.Status == choices.Accepted || state.Status == choices.Rejected,
    }
}

func (s *Server) getPreference(vertexID ids.ID) choices.Status {
    s.engine.mutex.RLock()
    defer s.engine.mutex.RUnlock()
    
    if state, exists := s.engine.vertices[vertexID]; exists {
        if state.Confidence > 0 {
            return choices.Accepted
        }
    }
    return choices.Rejected
}

func (s *Server) countVerticesByStatus(status choices.Status) int {
    count := 0
    for _, state := range s.engine.vertices {
        if state.Status == status {
            count++
        }
    }
    return count
} 