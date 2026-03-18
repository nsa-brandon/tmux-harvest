#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$(dirname "$CURRENT_DIR")/bin/harvest-tmux"

# Ensure UTF-8
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Theme - ayu dark palette
o='\e[38;2;230;126;34m'     # orange
w='\e[38;2;191;189;182m'    # warm white
b='\e[1;38;2;230;230;220m'  # bright
d='\e[38;2;86;91;102m'      # dim
c='\e[38;2;57;186;230m'     # cyan
g='\e[38;2;166;227;161m'    # green
r='\e[38;2;243;139;168m'    # red
y='\e[38;2;249;226;175m'    # yellow
n='\e[0m'                   # reset

# Get today's entries
entries=$("$BINARY" today 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$entries" ]; then
    printf "\n  ${d}No entries today.${n}\n"
    read -rsn1
    exit 1
fi

fzf_opts=(
    --no-sort --reverse
    --bind="q:abort"
    --color="fg:#BFBDB6,bg:#0B0E14,hl:#E67E22,fg+:#FFFFFF,bg+:#1A1E29,hl+:#E67E22,pointer:#E67E22,prompt:#E67E22,header:#565B66"
)

# Pick entry
selected=$(echo "$entries" | head -n -1 | \
    fzf --prompt="  Edit > " \
    --delimiter=$'\t' \
    --with-nth=2,3,4,5 \
    --header="Select entry to edit  |  q quit" \
    "${fzf_opts[@]}")

if [ -z "$selected" ]; then
    exit 0
fi

entry_id=$(echo "$selected" | cut -f1)
orig_hours=$(echo "$selected" | cut -f2)
orig_project=$(echo "$selected" | cut -f3)
orig_task=$(echo "$selected" | cut -f4)
orig_notes=$(echo "$selected" | cut -f5)

cur_project="$orig_project"
cur_task="$orig_task"
cur_hours="$orig_hours"
cur_notes="$orig_notes"

new_pid=""
new_tid=""

mod_project=false
mod_task=false
mod_hours=false
mod_notes=false

changes() {
    local n=0
    $mod_project && ((n++))
    $mod_task && ((n++))
    $mod_hours && ((n++))
    $mod_notes && ((n++))
    echo $n
}

show_menu() {
    clear

    local nc
    nc=$(changes)

    # Header
    printf "\n"
    printf "  ${o}Edit Entry${n}"
    if [ "$nc" -gt 0 ]; then
        printf "  ${d}|${n}  ${y}${nc} unsaved${n}"
    fi
    printf "\n"
    printf "  ${d}%.0s-${n}" $(seq 1 40)
    printf "\n\n"

    # Fields
    local mk val

    # Project
    if $mod_project; then mk="${y}*${n}"; val="${y}${cur_project}${n}"
    else mk=" "; val="${b}${cur_project}${n}"; fi
    printf "  ${mk} ${c}1${n}  ${d}Project${n}   ${val}\n"

    # Task
    if $mod_task; then mk="${y}*${n}"; val="${y}${cur_task}${n}"
    else mk=" "; val="${b}${cur_task}${n}"; fi
    printf "  ${mk} ${c}2${n}  ${d}Task${n}      ${val}\n"

    # Hours
    if $mod_hours; then mk="${y}*${n}"; val="${y}${cur_hours}${n}"
    else mk=" "; val="${b}${cur_hours}${n}"; fi
    printf "  ${mk} ${c}3${n}  ${d}Hours${n}     ${val}\n"

    # Notes
    local display_notes="$cur_notes"
    [ ${#display_notes} -gt 50 ] && display_notes="${display_notes:0:47}..."
    if $mod_notes; then mk="${y}*${n}"; val="${y}${display_notes}${n}"
    else mk=" "; val="${b}${display_notes}${n}"; fi
    printf "  ${mk} ${c}4${n}  ${d}Notes${n}     ${val}\n"

    # Footer
    printf "\n"
    printf "  ${d}%.0s-${n}" $(seq 1 40)
    printf "\n"
    if [ "$nc" -gt 0 ]; then
        printf "  ${g}s${n} ${w}save${n}    ${r}q${n} ${w}cancel${n}\n"
    else
        printf "  ${d}s save${n}    ${r}q${n} ${w}cancel${n}\n"
    fi
    printf "\n"
}

while true; do
    show_menu
    printf "  ${o}>${n} "
    read -rsn1 key

    case "$key" in
        1)
            projects_output=$("$BINARY" projects 2>/dev/null)
            [ -z "$projects_output" ] && continue
            project_line=$(echo "$projects_output" | fzf --prompt="  Project > " \
                --delimiter=$'\t' --with-nth=2,3 "${fzf_opts[@]}")
            if [ -n "$project_line" ]; then
                new_pid=$(echo "$project_line" | cut -f1)
                cur_project=$(echo "$project_line" | cut -f2)
                mod_project=true
                # Auto-prompt task for new project
                tasks_output=$("$BINARY" tasks "$new_pid" 2>/dev/null)
                if [ -n "$tasks_output" ]; then
                    task_line=$(echo "$tasks_output" | fzf --prompt="  Task > " \
                        --delimiter=$'\t' --with-nth=2 "${fzf_opts[@]}")
                    if [ -n "$task_line" ]; then
                        new_tid=$(echo "$task_line" | cut -f1)
                        cur_task=$(echo "$task_line" | cut -f2)
                        mod_task=true
                    fi
                fi
            fi
            ;;
        2)
            pid="${new_pid}"
            if [ -z "$pid" ]; then
                pid=$("$BINARY" projects 2>/dev/null | awk -F'\t' -v code="$cur_project" '$2 == code {print $1; exit}')
            fi
            [ -z "$pid" ] && continue
            tasks_output=$("$BINARY" tasks "$pid" 2>/dev/null)
            [ -z "$tasks_output" ] && continue
            task_line=$(echo "$tasks_output" | fzf --prompt="  Task > " \
                --delimiter=$'\t' --with-nth=2 "${fzf_opts[@]}")
            if [ -n "$task_line" ]; then
                new_tid=$(echo "$task_line" | cut -f1)
                cur_task=$(echo "$task_line" | cut -f2)
                mod_task=true
            fi
            ;;
        3)
            printf "\n"
            printf "  ${d}e.g. 1.5  1h30m  90m${n}\n"
            printf "  ${o}Hours${n} > "
            read -r input
            if [ -n "$input" ]; then
                cur_hours="$input"
                mod_hours=true
            fi
            ;;
        4)
            printf "\n"
            printf "  ${o}Notes${n} > "
            read -r input
            if [ -n "$input" ]; then
                cur_notes="$input"
                mod_notes=true
            fi
            ;;
        s|S)
            nc=$(changes)
            if [ "$nc" -eq 0 ]; then
                tmux display-message "Harvest: No changes"
                exit 0
            fi
            args=("$BINARY" edit "$entry_id")
            [ -n "$new_pid" ] && args+=(--project "$new_pid")
            [ -n "$new_tid" ] && args+=(--task "$new_tid")
            $mod_hours && args+=(--hours "$cur_hours")
            $mod_notes && args+=(--notes "$cur_notes")
            printf "\n  ${d}Saving...${n}\n"
            output=$("${args[@]}" 2>&1)
            if [ $? -eq 0 ]; then
                tmux refresh-client -S
                tmux display-message "Harvest: $(echo "$output" | tail -1)"
            else
                printf "\n  ${r}Error:${n} $output\n"
                read -rsn1
            fi
            exit 0
            ;;
        q|Q)
            exit 0
            ;;
    esac
done
