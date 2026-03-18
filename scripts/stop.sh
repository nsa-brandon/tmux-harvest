#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"
harvest_config=$(tmux show-option -gqv @harvest-config)
[ -n "$harvest_config" ] && export HARVEST_CONFIG="${harvest_config/#\~/$HOME}"

output=$("$BINARY" stop 2>&1)
if [ $? -eq 0 ]; then
    tmux refresh-client -S
    tmux display-message "Harvest: $(echo "$output" | tail -1)"
else
    tmux display-message "Harvest: $output"
fi
