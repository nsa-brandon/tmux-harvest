#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$CURRENT_DIR/bin/harvest-tmux"

# Auto-build if binary is missing
if [ ! -x "$BINARY" ]; then
    if command -v go &>/dev/null; then
        (cd "$CURRENT_DIR" && mkdir -p bin && go build -o bin/harvest-tmux ./cmd/harvest-tmux) 2>&1 | \
            while read -r line; do tmux display-message "harvest-tmux build: $line"; done
        if [ ! -x "$BINARY" ]; then
            tmux display-message "harvest-tmux: build failed — run 'go build' manually in $CURRENT_DIR"
            exit 1
        fi
    else
        tmux display-message "harvest-tmux: Go not found — cannot build binary"
        exit 1
    fi
fi

# Read user options with defaults
harvest_key=$(tmux show-option -gqv @harvest-key)
harvest_key="${harvest_key:-H}"

# Config file path (exported so all scripts/binary inherit it)
harvest_config=$(tmux show-option -gqv @harvest-config)
if [ -n "$harvest_config" ]; then
    tmux set-environment -g HARVEST_CONFIG "$harvest_config"
fi

# Bind prefix + key to menu
tmux bind-key "$harvest_key" run-shell "$CURRENT_DIR/scripts/menu.sh"
