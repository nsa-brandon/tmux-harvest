#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"
harvest_config=$(tmux show-option -gqv @harvest-config)
[ -n "$harvest_config" ] && export HARVEST_CONFIG="${harvest_config/#\~/$HOME}"

entries=$("$BINARY" today 2>&1)
if [ $? -ne 0 ]; then
    tmux display-message "Harvest: $entries"
    exit 1
fi

if [ -z "$entries" ]; then
    tmux display-message "Harvest: No entries today"
    exit 0
fi

# Strip entry ID column (first field) for display
echo "$entries" | cut -f2- | column -t -s $'\t' | fzf --no-sort --reverse \
    --header="Today's Time Log (Esc to close)" \
    --no-mouse \
    --bind="enter:abort,esc:abort,q:abort"
