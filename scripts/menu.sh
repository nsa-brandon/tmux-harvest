#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$CURRENT_DIR")"
BINARY="$PLUGIN_DIR/bin/harvest-tmux"

status=$("$BINARY" status 2>/dev/null)
state=$(echo "$status" | cut -d' ' -f1)
value=$(echo "$status" | cut -d' ' -f2)

if [ "$state" = "running" ]; then
    title="Harvest Timer ⏱ ${value}"
    tmux display-menu -T "$title" -x R -y S \
        "Stop timer"        s "run-shell '$CURRENT_DIR/stop.sh'" \
        "" \
        "Start new entry"   n "display-popup -E -w 60% -h 50% '$CURRENT_DIR/new-entry.sh'" \
        "Log time"          l "display-popup -E -w 60% -h 50% '$CURRENT_DIR/log-entry.sh'" \
        "Edit entry"        e "display-popup -E -w 40% -h 35% '$CURRENT_DIR/edit-entry.sh'" \
        "" \
        "View today's log"  v "display-popup -E -w 70% -h 50% '$CURRENT_DIR/daily.sh'"
else
    title="Harvest Timer (stopped)"
    tmux display-menu -T "$title" -x R -y S \
        "Resume last entry" r "run-shell '$CURRENT_DIR/resume.sh'" \
        "" \
        "Start new entry"   n "display-popup -E -w 60% -h 50% '$CURRENT_DIR/new-entry.sh'" \
        "Log time"          l "display-popup -E -w 60% -h 50% '$CURRENT_DIR/log-entry.sh'" \
        "Edit entry"        e "display-popup -E -w 40% -h 35% '$CURRENT_DIR/edit-entry.sh'" \
        "" \
        "View today's log"  v "display-popup -E -w 70% -h 50% '$CURRENT_DIR/daily.sh'"
fi
