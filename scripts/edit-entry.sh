#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"

# Get today's entries (TSV: entry_id, hours, project_code, task, notes)
entries=$("$BINARY" today 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$entries" ]; then
    echo "No entries today. Press enter to close."
    read -r
    exit 1
fi

# Remove TOTAL line, let user pick
selected=$(echo "$entries" | head -n -1 | \
    fzf --prompt="Edit entry> " \
    --delimiter=$'\t' \
    --with-nth=2,3,4,5 \
    --no-sort --reverse \
    --header="Select entry to edit (Esc to cancel)")

if [ -z "$selected" ]; then
    exit 0
fi

entry_id=$(echo "$selected" | cut -f1)
current_hours=$(echo "$selected" | cut -f2)
current_project=$(echo "$selected" | cut -f3)
current_task=$(echo "$selected" | cut -f4)
current_notes=$(echo "$selected" | cut -f5)

echo "Editing: ${current_project} / ${current_task} (${current_hours}h)"
echo "Notes: ${current_notes}"
echo ""
echo "Leave blank to keep current value. Type 'y' to pick new project/task."
echo ""

args=("$BINARY" edit "$entry_id")
changed=false

# Project
printf "Change project? [%s] (y/N): " "$current_project"
read -r change_project
if [ "$change_project" = "y" ] || [ "$change_project" = "Y" ]; then
    projects_output=$("$BINARY" projects 2>/dev/null)
    if [ -z "$projects_output" ]; then
        echo "Error fetching projects."
        read -r
        exit 1
    fi
    project_line=$(echo "$projects_output" | fzf --prompt="New Project> " \
        --delimiter=$'\t' --with-nth=2,3 --no-sort)
    if [ -n "$project_line" ]; then
        new_pid=$(echo "$project_line" | cut -f1)
        args+=(--project "$new_pid")
        changed=true

        # Pick task for new project
        tasks_output=$("$BINARY" tasks "$new_pid" 2>/dev/null)
        if [ -n "$tasks_output" ]; then
            task_line=$(echo "$tasks_output" | fzf --prompt="Task for new project> " \
                --delimiter=$'\t' --with-nth=2 --no-sort)
            if [ -n "$task_line" ]; then
                new_tid=$(echo "$task_line" | cut -f1)
                args+=(--task "$new_tid")
            fi
        fi
    fi
else
    # Task only
    printf "Change task? [%s] (y/N): " "$current_task"
    read -r change_task
    if [ "$change_task" = "y" ] || [ "$change_task" = "Y" ]; then
        current_pid=$(echo "$("$BINARY" projects 2>/dev/null)" | awk -F'\t' -v code="$current_project" '$2 == code {print $1; exit}')
        if [ -n "$current_pid" ]; then
            tasks_output=$("$BINARY" tasks "$current_pid" 2>/dev/null)
            if [ -n "$tasks_output" ]; then
                task_line=$(echo "$tasks_output" | fzf --prompt="New Task> " \
                    --delimiter=$'\t' --with-nth=2 --no-sort)
                if [ -n "$task_line" ]; then
                    new_tid=$(echo "$task_line" | cut -f1)
                    args+=(--task "$new_tid")
                    changed=true
                fi
            fi
        fi
    fi
fi

# Hours
printf "Hours [%s]: " "$current_hours"
read -r new_hours
if [ -n "$new_hours" ]; then
    args+=(--hours "$new_hours")
    changed=true
fi

# Notes
printf "Notes [%s]: " "$current_notes"
read -r new_notes
if [ -n "$new_notes" ]; then
    args+=(--notes "$new_notes")
    changed=true
fi

if [ "$changed" = false ]; then
    echo "No changes."
    sleep 1
    exit 0
fi

output=$("${args[@]}" 2>&1)
if [ $? -eq 0 ]; then
    tmux refresh-client -S
    tmux display-message "Harvest: $(echo "$output" | tail -1)"
else
    echo "Error: $output"
    echo "Press enter to close."
    read -r
fi
