package config

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type Config struct {
	AccountID string
	APIToken  string
}

func DefaultPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "harvest", "config.ini")
}

func Load() (*Config, error) {
	path := os.Getenv("HARVEST_CONFIG")
	if path == "" {
		path = DefaultPath()
	}
	return LoadFromPath(path)
}

func LoadFromPath(path string) (*Config, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("cannot open config: %w", err)
	}
	defer f.Close()

	var cfg Config
	inHarvestSection := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") {
			continue
		}
		if strings.HasPrefix(line, "[") {
			inHarvestSection = strings.EqualFold(line, "[harvest]")
			continue
		}
		if !inHarvestSection {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		switch key {
		case "account_id":
			cfg.AccountID = val
		case "api_token":
			cfg.APIToken = val
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading config: %w", err)
	}
	if cfg.AccountID == "" || cfg.APIToken == "" {
		return nil, fmt.Errorf("missing account_id or api_token in [Harvest] section of %s", path)
	}
	return &cfg, nil
}
