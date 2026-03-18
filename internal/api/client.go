package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/brandondedolph/tmux-harvest/internal/config"
)

const baseURL = "https://api.harvestapp.com/v2"

type Client struct {
	cfg  *config.Config
	http *http.Client
}

func NewClient(cfg *config.Config) *Client {
	return &Client{
		cfg:  cfg,
		http: &http.Client{Timeout: 10 * time.Second},
	}
}

func (c *Client) do(method, path string, body string) ([]byte, error) {
	var bodyReader io.Reader
	if body != "" {
		bodyReader = strings.NewReader(body)
	}
	req, err := http.NewRequest(method, baseURL+path, bodyReader)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.cfg.APIToken)
	req.Header.Set("Harvest-Account-Id", c.cfg.AccountID)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "tmux-harvest")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("API request failed: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response: %w", err)
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(data))
	}
	return data, nil
}

type TimeEntry struct {
	ID             int64   `json:"id"`
	SpentDate      string  `json:"spent_date"`
	Hours          float64 `json:"hours"`
	Notes          string  `json:"notes"`
	IsRunning      bool    `json:"is_running"`
	TimerStartedAt *string `json:"timer_started_at"`
	Project        struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
		Code string `json:"code"`
	} `json:"project"`
	Task struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	} `json:"task"`
}

type timeEntriesResponse struct {
	TimeEntries []TimeEntry `json:"time_entries"`
}

type ProjectAssignment struct {
	Project struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
		Code string `json:"code"`
	} `json:"project"`
	TaskAssignments []struct {
		Task struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"task"`
	} `json:"task_assignments"`
}

type projectAssignmentsResponse struct {
	ProjectAssignments []ProjectAssignment `json:"project_assignments"`
	TotalPages         int                 `json:"total_pages"`
	Page               int                 `json:"page"`
}

func (c *Client) TodayEntries() ([]TimeEntry, error) {
	today := time.Now().Format("2006-01-02")
	data, err := c.do("GET", "/time_entries?from="+today+"&to="+today+"&sort=updated_at&direction=desc", "")
	if err != nil {
		return nil, err
	}
	var resp timeEntriesResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, fmt.Errorf("parsing entries: %w", err)
	}
	return resp.TimeEntries, nil
}

func (c *Client) RunningTimer() (*TimeEntry, error) {
	data, err := c.do("GET", "/time_entries?is_running=true", "")
	if err != nil {
		return nil, err
	}
	var resp timeEntriesResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, fmt.Errorf("parsing entries: %w", err)
	}
	if len(resp.TimeEntries) == 0 {
		return nil, nil
	}
	return &resp.TimeEntries[0], nil
}

func (c *Client) ProjectAssignments() ([]ProjectAssignment, error) {
	var all []ProjectAssignment
	page := 1
	for {
		data, err := c.do("GET", fmt.Sprintf("/users/me/project_assignments?is_active=true&page=%d", page), "")
		if err != nil {
			return nil, err
		}
		var resp projectAssignmentsResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return nil, fmt.Errorf("parsing assignments: %w", err)
		}
		all = append(all, resp.ProjectAssignments...)
		if page >= resp.TotalPages {
			break
		}
		page++
	}
	return all, nil
}

func (c *Client) StopTimer(entryID int64) (*TimeEntry, error) {
	data, err := c.do("PATCH", fmt.Sprintf("/time_entries/%d/stop", entryID), "")
	if err != nil {
		return nil, err
	}
	var entry TimeEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil, fmt.Errorf("parsing entry: %w", err)
	}
	return &entry, nil
}

func (c *Client) RestartTimer(entryID int64) (*TimeEntry, error) {
	data, err := c.do("PATCH", fmt.Sprintf("/time_entries/%d/restart", entryID), "")
	if err != nil {
		return nil, err
	}
	var entry TimeEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil, fmt.Errorf("parsing entry: %w", err)
	}
	return &entry, nil
}

func (c *Client) CreateEntry(projectID, taskID int64, notes string) (*TimeEntry, error) {
	today := time.Now().Format("2006-01-02")
	body := fmt.Sprintf(`{"project_id":%d,"task_id":%d,"spent_date":"%s","notes":%s,"is_running":true}`,
		projectID, taskID, today, jsonString(notes))
	data, err := c.do("POST", "/time_entries", body)
	if err != nil {
		return nil, err
	}
	var entry TimeEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil, fmt.Errorf("parsing entry: %w", err)
	}
	return &entry, nil
}

func jsonString(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}
