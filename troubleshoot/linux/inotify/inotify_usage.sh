#!/usr/bin/env bash
set -euo pipefail

export LC_NUMERIC=en_US.UTF-8

inotify_usage() {
    echo "NOTE: This script can take a couple minutes."
    echo "=== inotify Limits & Usage ==="
    echo

    local max_watches max_instances max_queued
    max_watches=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "0")
    max_instances=$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo "0")
    max_queued=$(cat /proc/sys/fs/inotify/max_queued_events 2>/dev/null || echo "0")

    local total_instances=0
    local total_watches=0
    declare -A pid_instances
    declare -A pid_watches

    for pid in /proc/[0-9]*; do
        [[ -d "$pid" ]] || continue
        local pid_num="${pid##*/}"
        local fd_dir="$pid/fd"
        [[ -d "$fd_dir" ]] || continue

        local instances=0
        local watches=0

        for fd in "$fd_dir"/*; do
            if [[ -L "$fd" ]] && readlink "$fd" 2>/dev/null | grep -q 'anon_inode:inotify'; then
                ((instances++))
                # Count actual watches from fdinfo
                local fd_num="${fd##*/}"
                local fdinfo="$pid/fdinfo/$fd_num"
                if [[ -r "$fdinfo" ]]; then
                    local watch_count
                    watch_count=$(grep -c '^inotify wd:' "$fdinfo" 2>/dev/null || echo "0")
                    watches=$((watches + watch_count))
                fi
            fi
        done

        if [[ $instances -gt 0 ]]; then
            pid_instances[$pid_num]=$instances
            pid_watches[$pid_num]=$watches
            total_instances=$((total_instances + instances))
            total_watches=$((total_watches + watches))
        fi
    done

    echo "Top Consumers (sorted by instances):"
    printf "%-8s %-6s %-40s %10s %10s\n" "USER" "PID" "COMMAND" "INSTANCES" "WATCHES"
    printf "%s\n" "$(printf '%.0s-' {1..80})"

    for pid_num in "${!pid_instances[@]}"; do
        printf "%s %s\n" "${pid_instances[$pid_num]}" "$pid_num"
    done | sort -rn | while read -r count pid_num; do
        local user cmd
        user=$(ps -o user= -p "$pid_num" 2>/dev/null || echo "?")
        cmd=$(ps -o comm= -p "$pid_num" 2>/dev/null || echo "?")

        printf "%-8s %-6s %-40s %'10d %'10d\n" \
            "$user" "$pid_num" "$cmd" \
            "${pid_instances[$pid_num]}" "${pid_watches[$pid_num]}"
    done

    echo
    echo "Limits:"

    if [[ "$max_watches" != "0" ]]; then
        printf "  max_user_watches:    %'d / %'d" "$total_watches" "$max_watches"
        local watch_percent=$((total_watches * 100 / max_watches))
        printf " (%d%%)" "$watch_percent"
        [[ $watch_percent -gt 80 ]] && printf " ⚠️"
        echo
    fi

    if [[ "$max_instances" != "0" ]]; then
        printf "  max_user_instances:  %'d / %'d" "$total_instances" "$max_instances"
        local inst_percent=$((total_instances * 100 / max_instances))
        printf " (%d%%)" "$inst_percent"
        [[ $inst_percent -gt 80 ]] && printf " ⚠️"
        echo
    fi

    printf "  max_queued_events:   N/A / %'d\n" "$max_queued"
    echo
}

main() {
    inotify_usage
}

main "$@"