#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"

# Step 1: Pick project
projects_output=$("$BINARY" projects 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$projects_output" ]; then
    echo "Error: Failed to fetch projects. Press enter to close."
    read -r
    exit 1
fi

project_line=$(echo "$projects_output" | fzf --prompt="Project> " \
    --delimiter=$'\t' \
    --with-nth=2,3 \
    --no-sort \
    --bind="q:abort")

if [ -z "$project_line" ]; then
    exit 0
fi

project_id=$(echo "$project_line" | cut -f1)

# Step 2: Pick task
tasks_output=$("$BINARY" tasks "$project_id" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$tasks_output" ]; then
    echo "Error: Failed to fetch tasks. Press enter to close."
    read -r
    exit 1
fi

task_line=$(echo "$tasks_output" | fzf --prompt="Task> " \
    --delimiter=$'\t' \
    --with-nth=2 \
    --no-sort \
    --bind="q:abort")

if [ -z "$task_line" ]; then
    exit 0
fi

task_id=$(echo "$task_line" | cut -f1)

# Step 3: Optional notes
printf "Notes (optional): "
read -r notes

# Step 4: Start entry
args=("$BINARY" start "$project_id" "$task_id")
if [ -n "$notes" ]; then
    args+=(-n "$notes")
fi

output=$("${args[@]}" 2>&1)
if [ $? -eq 0 ]; then
    tmux refresh-client -S
    tmux display-message "Harvest: $(echo "$output" | tail -1)"
else
    tmux display-message "Harvest: $output"
fi
