// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package worker

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/ava-labs/avalanchego/utils/logging"
)

// Client provides communication with worker services
type Client struct {
	baseURL     string
	httpClient  *http.Client
	logger      logging.Logger
	concurrency int
}

// ClientOption is a function that configures a Client
type ClientOption func(*Client)

// WithConcurrency sets the maximum number of concurrent requests
func WithConcurrency(n int) ClientOption {
	return func(c *Client) {
		if n > 0 {
			c.concurrency = n
		}
	}
}

// WithTimeout sets the HTTP client timeout
func WithTimeout(timeout time.Duration) ClientOption {
	return func(c *Client) {
		c.httpClient.Timeout = timeout
	}
}

// NewClient creates a new worker client
func NewClient(baseURL string, logger logging.Logger, options ...ClientOption) *Client {
	client := &Client{
		baseURL: strings.TrimSuffix(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
		logger:      logger,
		concurrency: 10, // Default concurrency
	}

	// Apply options
	for _, option := range options {
		option(client)
	}

	return client
}

// TaskRequest represents a task submission request
type TaskRequest struct {
	Payload []byte `json:"payload"`
}

// TaskResponse represents the response from a task submission
type TaskResponse struct {
	TaskID string `json:"task_id"`
	Status string `json:"status"`
}

// SubmitTask submits a task to the worker service
func (c *Client) SubmitTask(ctx context.Context, payload []byte) (string, error) {
	reqData := TaskRequest{
		Payload: payload,
	}

	reqBody, err := json.Marshal(reqData)
	if err != nil {
		return "", fmt.Errorf("failed to marshal task request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/tasks", strings.NewReader(string(reqBody)))
	if err != nil {
		return "", fmt.Errorf("failed to create task request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to submit task: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	var taskResp TaskResponse
	if err := json.NewDecoder(resp.Body).Decode(&taskResp); err != nil {
		return "", fmt.Errorf("failed to decode task response: %w", err)
	}

	return taskResp.TaskID, nil
}

// GetTaskResult retrieves the result of a task
func (c *Client) GetTaskResult(ctx context.Context, taskID string) (*Result, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s/tasks/%s", c.baseURL, taskID), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create result request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get task result: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		return nil, fmt.Errorf("task not found: %s", taskID)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", resp.StatusCode, string(body))
	}

	var result Result
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode task result: %w", err)
	}

	return &result, nil
}

// Health checks the health of the worker service
func (c *Client) Health(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/health", nil)
	if err != nil {
		return fmt.Errorf("failed to create health request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to check health: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("worker service is unhealthy: status code %d", resp.StatusCode)
	}

	return nil
} 