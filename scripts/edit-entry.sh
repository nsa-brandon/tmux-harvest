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

# Pick entry
selected=$(echo "$entries" | head -n -1 | \
    fzf --prompt="Edit entry> " \
    --delimiter=$'\t' \
    --with-nth=2,3,4,5 \
    --no-sort --reverse \
    --header="Select entry to edit")

if [ -z "$selected" ]; then
    exit 0
fi

entry_id=$(echo "$selected" | cut -f1)
edit_hours=$(echo "$selected" | cut -f2)
edit_project_code=$(echo "$selected" | cut -f3)
edit_task=$(echo "$selected" | cut -f4)
edit_notes=$(echo "$selected" | cut -f5)

# Track changes
new_pid=""
new_tid=""
new_hours=""
new_notes=""

while true; do
    # Build field menu showing current (or edited) values
    display_hours="${new_hours:-$edit_hours}"
    display_project="${edit_project_code}"
    display_task="${edit_task}"
    display_notes="${new_notes:-$edit_notes}"

    # Truncate notes for display
    short_notes="$display_notes"
    if [ ${#short_notes} -gt 50 ]; then
        short_notes="${short_notes:0:47}..."
    fi

    choice=$(printf "Project\t%s\nTask\t%s\nHours\t%s\nNotes\t%s\n─\n✓ Save changes\n✗ Cancel" \
        "$display_project" "$display_task" "$display_hours" "$short_notes" | \
        fzf --no-sort --reverse \
            --delimiter=$'\t' \
            --with-nth=1,2 \
            --header="Pick a field to edit" \
            --prompt="→ ")

    if [ -z "$choice" ]; then
        exit 0
    fi

    field=$(echo "$choice" | cut -f1)

    case "$field" in
        "Project")
            projects_output=$("$BINARY" projects 2>/dev/null)
            if [ -z "$projects_output" ]; then
                continue
            fi
            project_line=$(echo "$projects_output" | fzf --prompt="Project> " \
                --delimiter=$'\t' --with-nth=2,3 --no-sort)
            if [ -n "$project_line" ]; then
                new_pid=$(echo "$project_line" | cut -f1)
                edit_project_code=$(echo "$project_line" | cut -f2)
                # Auto-prompt for task on new project
                tasks_output=$("$BINARY" tasks "$new_pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="Task> " \
                        --delimiter=$'\t' --with-nth=2 --no-sort)
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                    fi
                fi
            fi
            ;;
        "Task")
            # Look up current project ID
            pid="${new_pid}"
            if [ -z "$pid" ]; then
                pid=$(echo "$("$BINARY" projects 2>/dev/null)" | awk -F'\t' -v code="$edit_project_code" '$2 == code {print $1; exit}')
            fi
            if [ -n "$pid" ]; then
                tasks_output=$("$BINARY" tasks "$pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="Task> " \
                        --delimiter=$'\t' --with-nth=2 --no-sort)
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                    fi
                fi
            fi
            ;;
        "Hours")
            printf "Hours [%s]: " "$display_hours"
            read -r input
            if [ -n "$input" ]; then
                new_hours="$input"
            fi
            ;;
        "Notes")
            printf "Notes [%s]: " "$display_notes"
            read -r input
            if [ -n "$input" ]; then
                new_notes="$input"
            fi
            ;;
        "✓ Save changes")
            args=("$BINARY" edit "$entry_id")
            changed=false
            if [ -n "$new_pid" ]; then
                args+=(--project "$new_pid")
                changed=true
            fi
            if [ -n "$new_tid" ]; then
                args+=(--task "$new_tid")
                changed=true
            fi
            if [ -n "$new_hours" ]; then
                args+=(--hours "$new_hours")
                changed=true
            fi
            if [ -n "$new_notes" ]; then
                args+=(--notes "$new_notes")
                changed=true
            fi
            if [ "$changed" = false ]; then
                tmux display-message "Harvest: No changes"
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
            exit 0
            ;;
        "✗ Cancel")
            exit 0
            ;;
    esac
done
