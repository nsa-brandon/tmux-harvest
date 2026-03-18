#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"

output=$("$BINARY" resume 2>&1)
if [ $? -eq 0 ]; then
    tmux refresh-client -S
    tmux display-message "Harvest: $(echo "$output" | tail -1)"
else
    tmux display-message "Harvest: $output"
fi
