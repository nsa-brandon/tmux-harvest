#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"

# Colors
ORANGE='\033[38;2;230;126;34m'
DIM_ORANGE='\033[38;2;139;90;43m'
WHITE='\033[1;37m'
DIM='\033[2m'
CYAN='\033[38;2;57;186;230m'
GREEN='\033[38;2;166;227;161m'
RED='\033[38;2;243;139;168m'
YELLOW='\033[38;2;249;226;175m'
RESET='\033[0m'
BOLD='\033[1m'

# Get today's entries
entries=$("$BINARY" today 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$entries" ]; then
    echo -e "\n  ${DIM}No entries today.${RESET}\n"
    read -rsn1
    exit 1
fi

# Pick entry via fzf
selected=$(echo "$entries" | head -n -1 | \
    fzf --prompt="  Edit > " \
    --delimiter=$'\t' \
    --with-nth=2,3,4,5 \
    --no-sort --reverse \
    --header="Select entry to edit (q to quit)" \
    --bind="q:abort" \
    --color="fg:#BFBDB6,bg:#0B0E14,hl:#E67E22,fg+:#FFFFFF,bg+:#1A1E29,hl+:#E67E22,pointer:#E67E22,prompt:#E67E22,header:#565B66")

if [ -z "$selected" ]; then
    exit 0
fi

entry_id=$(echo "$selected" | cut -f1)
edit_hours=$(echo "$selected" | cut -f2)
edit_project_code=$(echo "$selected" | cut -f3)
edit_task=$(echo "$selected" | cut -f4)
edit_notes=$(echo "$selected" | cut -f5)

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

    # Truncate notes
    short_notes="$display_notes"
    if [ ${#short_notes} -gt 60 ]; then
        short_notes="${short_notes:0:57}..."
    fi

    echo ""
    echo -e "  ${ORANGE}${BOLD}Edit Entry${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${CYAN}1${RESET}  ${DIM}Project${RESET}   ${WHITE}${display_project}${RESET}"
    echo -e "  ${CYAN}2${RESET}  ${DIM}Task${RESET}      ${WHITE}${display_task}${RESET}"
    echo -e "  ${CYAN}3${RESET}  ${DIM}Hours${RESET}     ${WHITE}${display_hours}${RESET}"
    echo -e "  ${CYAN}4${RESET}  ${DIM}Notes${RESET}     ${WHITE}${short_notes}${RESET}"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────${RESET}"
    echo -e "  ${GREEN}s${RESET}  Save     ${RED}q${RESET}  Cancel"
    echo ""
}

fzf_theme="--color=fg:#BFBDB6,bg:#0B0E14,hl:#E67E22,fg+:#FFFFFF,bg+:#1A1E29,hl+:#E67E22,pointer:#E67E22,prompt:#E67E22,header:#565B66"

while true; do
    show_menu
    printf "  ${ORANGE}›${RESET} "
    read -rsn1 key

    case "$key" in
        1)
            projects_output=$("$BINARY" projects 2>/dev/null)
            if [ -z "$projects_output" ]; then
                continue
            fi
            project_line=$(echo "$projects_output" | fzf --prompt="  Project > " \
                --delimiter=$'\t' --with-nth=2,3 --no-sort \
                --bind="q:abort" $fzf_theme)
            if [ -n "$project_line" ]; then
                new_pid=$(echo "$project_line" | cut -f1)
                edit_project_code=$(echo "$project_line" | cut -f2)
                tasks_output=$("$BINARY" tasks "$new_pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="  Task > " \
                        --delimiter=$'\t' --with-nth=2 --no-sort \
                        --bind="q:abort" $fzf_theme)
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                    fi
                fi
            fi
            ;;
        2)
            pid="${new_pid}"
            if [ -z "$pid" ]; then
                pid=$(echo "$("$BINARY" projects 2>/dev/null)" | awk -F'\t' -v code="$edit_project_code" '$2 == code {print $1; exit}')
            fi
            if [ -n "$pid" ]; then
                tasks_output=$("$BINARY" tasks "$pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="  Task > " \
                        --delimiter=$'\t' --with-nth=2 --no-sort \
                        --bind="q:abort" $fzf_theme)
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                    fi
                fi
            fi
            ;;
        3)
            echo ""
            printf "  ${ORANGE}Hours${RESET} ${DIM}(1.5, 1h30m, 90m)${RESET}: "
            read -r input
            if [ -n "$input" ]; then
                new_hours="$input"
            fi
            ;;
        4)
            echo ""
            printf "  ${ORANGE}Notes${RESET}: "
            read -r input
            if [ -n "$input" ]; then
                new_notes="$input"
            fi
            ;;
        s|S)
            args=("$BINARY" edit "$entry_id")
            changed=false
            [ -n "$new_pid" ] && args+=(--project "$new_pid") && changed=true
            [ -n "$new_tid" ] && args+=(--task "$new_tid") && changed=true
            [ -n "$new_hours" ] && args+=(--hours "$new_hours") && changed=true
            [ -n "$new_notes" ] && args+=(--notes "$new_notes") && changed=true
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
                echo -e "  ${RED}Error:${RESET} $output"
                read -rsn1
            fi
            exit 0
            ;;
        q|Q)
            exit 0
            ;;
    esac
done
