#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"

# Theme — matches dotbar/ayu dark palette
ORANGE='\033[38;2;230;126;34m'
DIM_ORANGE='\033[38;2;139;90;43m'
WHITE='\033[38;2;191;189;182m'
BRIGHT='\033[1;38;2;230;230;220m'
DIM='\033[38;2;86;91;102m'
CYAN='\033[38;2;57;186;230m'
GREEN='\033[38;2;166;227;161m'
RED='\033[38;2;243;139;168m'
YELLOW='\033[38;2;249;226;175m'
BG_SUBTLE='\033[48;2;20;24;33m'
RESET='\033[0m'
BOLD='\033[1m'
ITALIC='\033[3m'

# Box chars
TL='╭' TR='╮' BL='╰' BR='╯' H='─' V='│' VL='├' VR='┤'

W=46  # inner width

hline() { printf '%*s' "$W" '' | tr ' ' "$H"; }
padded() {
    local text="$1" max="$2"
    local stripped
    stripped=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#stripped}
    local pad=$((max - len))
    [ "$pad" -lt 0 ] && pad=0
    printf '%s%*s' "$text" "$pad" ''
}

# Get today's entries
entries=$("$BINARY" today 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$entries" ]; then
    echo -e "\n  ${DIM}No entries today.${RESET}\n"
    read -rsn1
    exit 1
fi

fzf_theme="--color=fg:#BFBDB6,bg:#0B0E14,hl:#E67E22,fg+:#FFFFFF,bg+:#1A1E29,hl+:#E67E22,pointer:#E67E22,prompt:#E67E22,header:#565B66,border:#2A2E38"

# Pick entry via fzf
selected=$(echo "$entries" | head -n -1 | \
    fzf --prompt="  ⏱ Edit > " \
    --delimiter=$'\t' \
    --with-nth=2,3,4,5 \
    --no-sort --reverse \
    --header="Select entry to edit" \
    --bind="q:abort" \
    --border=rounded \
    --margin=1,2 \
    --padding=0,1 \
    $fzf_theme)

if [ -z "$selected" ]; then
    exit 0
fi

entry_id=$(echo "$selected" | cut -f1)
orig_hours=$(echo "$selected" | cut -f2)
orig_project=$(echo "$selected" | cut -f3)
orig_task=$(echo "$selected" | cut -f4)
orig_notes=$(echo "$selected" | cut -f5)

edit_project_code="$orig_project"
edit_task="$orig_task"

new_pid=""
new_tid=""
new_hours=""
new_notes=""

# Track which fields were modified
mod_project=false
mod_task=false
mod_hours=false
mod_notes=false

field_val() {
    local modified="$1" new_val="$2" orig_val="$3"
    if [ "$modified" = true ]; then
        echo -e "${YELLOW}${new_val}${RESET}"
    else
        echo -e "${BRIGHT}${orig_val}${RESET}"
    fi
}

mod_marker() {
    if [ "$1" = true ]; then
        echo -e "${YELLOW}●${RESET}"
    else
        echo -e "${DIM}○${RESET}"
    fi
}

change_count() {
    local n=0
    [ "$mod_project" = true ] && ((n++))
    [ "$mod_task" = true ] && ((n++))
    [ "$mod_hours" = true ] && ((n++))
    [ "$mod_notes" = true ] && ((n++))
    echo "$n"
}

show_menu() {
    clear
    local d_hours d_project d_task d_notes
    d_hours="${new_hours:-$orig_hours}"
    d_project="${edit_project_code}"
    d_task="${edit_task}"
    d_notes="${new_notes:-$orig_notes}"

    # Truncate notes
    local short_notes="$d_notes"
    if [ ${#short_notes} -gt 34 ]; then
        short_notes="${short_notes:0:31}..."
    fi

    local changes
    changes=$(change_count)

    echo ""
    echo -e "  ${DIM}${TL}$(hline)${TR}${RESET}"
    echo -e "  ${DIM}${V}${RESET}  ${ORANGE}${BOLD}⏱ Edit Entry${RESET}$(printf '%*s' $((W - 14)) '')${DIM}${V}${RESET}"
    echo -e "  ${DIM}${VL}$(hline)${VR}${RESET}"
    echo ""
    echo -e "  ${DIM}${V}${RESET}  $(mod_marker $mod_project) ${CYAN}${BOLD}1${RESET}  ${DIM}Project${RESET}  $(padded "$(field_val $mod_project "$d_project" "$d_project")" 28)  ${DIM}${V}${RESET}"
    echo -e "  ${DIM}${V}${RESET}  $(mod_marker $mod_task) ${CYAN}${BOLD}2${RESET}  ${DIM}Task${RESET}     $(padded "$(field_val $mod_task "$d_task" "$d_task")" 28)  ${DIM}${V}${RESET}"
    echo -e "  ${DIM}${V}${RESET}  $(mod_marker $mod_hours) ${CYAN}${BOLD}3${RESET}  ${DIM}Hours${RESET}    $(padded "$(field_val $mod_hours "$d_hours" "$d_hours")" 28)  ${DIM}${V}${RESET}"
    echo -e "  ${DIM}${V}${RESET}  $(mod_marker $mod_notes) ${CYAN}${BOLD}4${RESET}  ${DIM}Notes${RESET}    $(padded "$(field_val $mod_notes "$short_notes" "$short_notes")" 28)  ${DIM}${V}${RESET}"
    echo ""
    echo -e "  ${DIM}${VL}$(hline)${VR}${RESET}"

    if [ "$changes" -gt 0 ]; then
        echo -e "  ${DIM}${V}${RESET}  ${GREEN}${BOLD}s${RESET} ${GREEN}Save${RESET} ${DIM}(${changes} change$([ "$changes" -ne 1 ] && echo s))${RESET}$(printf '%*s' $((W - 19 - ${#changes})) '')${RED}q${RESET} ${RED}Cancel${RESET}   ${DIM}${V}${RESET}"
    else
        echo -e "  ${DIM}${V}${RESET}  ${DIM}s Save (no changes)${RESET}$(printf '%*s' $((W - 30)) '')${RED}q${RESET} ${RED}Cancel${RESET}   ${DIM}${V}${RESET}"
    fi

    echo -e "  ${DIM}${BL}$(hline)${BR}${RESET}"
    echo ""
}

while true; do
    show_menu
    printf "  ${ORANGE}❯${RESET} "
    read -rsn1 key

    case "$key" in
        1)
            projects_output=$("$BINARY" projects 2>/dev/null)
            if [ -z "$projects_output" ]; then
                continue
            fi
            project_line=$(echo "$projects_output" | fzf --prompt="  Project > " \
                --delimiter=$'\t' --with-nth=2,3 --no-sort \
                --bind="q:abort" --border=rounded --margin=1,2 --padding=0,1 \
                $fzf_theme)
            if [ -n "$project_line" ]; then
                new_pid=$(echo "$project_line" | cut -f1)
                edit_project_code=$(echo "$project_line" | cut -f2)
                mod_project=true
                tasks_output=$("$BINARY" tasks "$new_pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="  Task > " \
                        --delimiter=$'\t' --with-nth=2 --no-sort \
                        --bind="q:abort" --border=rounded --margin=1,2 --padding=0,1 \
                        $fzf_theme)
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                        mod_task=true
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
                        --bind="q:abort" --border=rounded --margin=1,2 --padding=0,1 \
                        $fzf_theme)
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        edit_task=$(echo "$task_line" | cut -f2)
                        mod_task=true
                    fi
                fi
            fi
            ;;
        3)
            echo ""
            printf "  ${ORANGE}Hours${RESET} ${DIM}(1.5, 1h30m, 90m)${RESET} ${ORANGE}❯${RESET} "
            read -r input
            if [ -n "$input" ]; then
                new_hours="$input"
                mod_hours=true
            fi
            ;;
        4)
            echo ""
            printf "  ${ORANGE}Notes${RESET} ${ORANGE}❯${RESET} "
            read -r input
            if [ -n "$input" ]; then
                new_notes="$input"
                mod_notes=true
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
            echo ""
            echo -e "  ${DIM}Saving...${RESET}"
            output=$("${args[@]}" 2>&1)
            if [ $? -eq 0 ]; then
                tmux refresh-client -S
                tmux display-message "Harvest: $(echo "$output" | tail -1)"
            else
                echo ""
                echo -e "  ${RED}✗ Error:${RESET} $output"
                read -rsn1
            fi
            exit 0
            ;;
        q|Q)
            exit 0
            ;;
    esac
done
