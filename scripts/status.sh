#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$CURRENT_DIR")"
BINARY="$PLUGIN_DIR/bin/harvest-tmux"

color=$(tmux show-option -gqv @harvest-color)
dim_color=$(tmux show-option -gqv @harvest-dim-color)
color="${color:-#E67E22}"
dim_color="${dim_color:-#8B5A2B}"

status=$("$BINARY" status 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$status" ]; then
    echo "#[fg=${dim_color}]--"
    exit 0
fi

state=$(echo "$status" | cut -d' ' -f1)
value=$(echo "$status" | cut -d' ' -f2)

if [ "$state" = "running" ]; then
    echo "#[fg=${color}]⏱ ${value}"
else
    echo "#[fg=${dim_color}]${value}h"
fi
