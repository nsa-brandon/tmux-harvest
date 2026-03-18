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

# Pick entry via fzf
selected=$(echo "$entries" | head -n -1 | \
    fzf --prompt="Edit entry> " \
    --delimiter=$'\t' \
    --with-nth=2,3,4,5 \
    --no-sort --reverse \
    --header="Select entry to edit (q to quit)" \
    --bind="q:abort")

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

show_menu() {
    clear
    display_hours="${new_hours:-$edit_hours}"
    display_project="${edit_project_code}"
    display_task="${edit_task}"
    display_notes="${new_notes:-$edit_notes}"

    echo "  Editing: ${display_project} / ${display_task} (${display_hours}h)"
    echo ""
    echo "  1) Project    ${display_project}"
    echo "  2) Task       ${display_task}"
    echo "  3) Hours      ${display_hours}"
    echo "  4) Notes      ${display_notes}"
    echo ""
    echo "  s) Save"
    echo "  q) Cancel"
    echo ""
}

while true; do
    show_menu
    printf "  > "
    read -rsn1 key

    case "$key" in
        1)
            echo ""
            projects_output=$("$BINARY" projects 2>/dev/null)
            if [ -z "$projects_output" ]; then
                echo "  Error fetching projects."
                sleep 1
                continue
            fi
            project_line=$(echo "$projects_output" | fzf --prompt="Project> " \
                --delimiter=$'\t' --with-nth=2,3 --no-sort \
                --bind="q:abort")
            if [ -n "$project_line" ]; then
                new_pid=$(echo "$project_line" | cut -f1)
                edit_project_code=$(echo "$project_line" | cut -f2)
                # Auto-prompt for task on new project
                tasks_output=$("$BINARY" tasks "$new_pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="Task> " \
                        --delimiter=$'\t' --with-nth=2 --no-sort \
                        --bind="q:abort")
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                    fi
                fi
            fi
            ;;
        2)
            echo ""
            pid="${new_pid}"
            if [ -z "$pid" ]; then
                pid=$(echo "$("$BINARY" projects 2>/dev/null)" | awk -F'\t' -v code="$edit_project_code" '$2 == code {print $1; exit}')
            fi
            if [ -n "$pid" ]; then
                tasks_output=$("$BINARY" tasks "$pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="Task> " \
                        --delimiter=$'\t' --with-nth=2 --no-sort \
                        --bind="q:abort")
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                    fi
                fi
            fi
            ;;
        3)
            echo ""
            printf "  Hours (e.g. 1.5, 1h30m, 90m): "
            read -r input
            if [ -n "$input" ]; then
                new_hours="$input"
            fi
            ;;
        4)
            echo ""
            printf "  Notes: "
            read -r input
            if [ -n "$input" ]; then
                new_notes="$input"
            fi
            ;;
        s|S)
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
                echo ""
                echo "  Error: $output"
                echo "  Press any key to close."
                read -rsn1
            fi
            exit 0
            ;;
        q|Q)
            exit 0
            ;;
    esac
done
