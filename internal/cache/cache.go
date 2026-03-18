package cache

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type entry struct {
	Data      json.RawMessage `json:"data"`
	ExpiresAt time.Time       `json:"expires_at"`
}

var cacheDir string

func init() {
	home, _ := os.UserHomeDir()
	cacheDir = filepath.Join(home, ".cache", "harvest-tmux")
}

func path(key string) string {
	return filepath.Join(cacheDir, key+".json")
}

func Get(key string, dest interface{}) bool {
	data, err := os.ReadFile(path(key))
	if err != nil {
		return false
	}
	var e entry
	if err := json.Unmarshal(data, &e); err != nil {
		return false
	}
	if time.Now().After(e.ExpiresAt) {
		return false
	}
	return json.Unmarshal(e.Data, dest) == nil
}

func Set(key string, val interface{}, ttl time.Duration) error {
	data, err := json.Marshal(val)
	if err != nil {
		return fmt.Errorf("marshaling cache value: %w", err)
	}
	e := entry{
		Data:      data,
		ExpiresAt: time.Now().Add(ttl),
	}
	out, err := json.Marshal(e)
	if err != nil {
		return fmt.Errorf("marshaling cache entry: %w", err)
	}
	if err := os.MkdirAll(cacheDir, 0700); err != nil {
		return fmt.Errorf("creating cache dir: %w", err)
	}
	return os.WriteFile(path(key), out, 0600)
}

func Invalidate(key string) {
	os.Remove(path(key))
}
