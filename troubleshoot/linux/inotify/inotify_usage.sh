#!/usr/bin/env bash

inotify_usage() {
    echo "NOTE: This script can take a couple minutes."

    echo "=== inotify Limits & Usage ==="
    echo

    # System limits - will be updated with current values later
    local max_watches=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "N/A")
    local max_instances=$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo "N/A")
    local max_queued=$(cat /proc/sys/fs/inotify/max_queued_events 2>/dev/null || echo "N/A")

    # Current usage - collect data in one pass
    local total_instances=0
    local total_watches=0
    declare -A pid_instances
    declare -A pid_watches

    for pid in /proc/[0-9]*; do
        [[ -d "$pid" ]] || continue

        local pid_num="${pid##*/}"
        local fd_dir="$pid/fd"

        [[ -d "$fd_dir" ]] || continue

        # Count inotify instances and watches for this process
        local instances=0
        local watches=0

        if [[ -r "$fd_dir" ]]; then
            for fd in "$fd_dir"/*; do
                if [[ -L "$fd" ]] && readlink "$fd" 2>/dev/null | grep -q 'anon_inode:inotify'; then
                    ((instances++))
                    # Count watches for this inotify instance (one watch per symlink)
                    ((watches++))
                fi
            done
        fi

        if [[ $instances -gt 0 ]]; then
            pid_instances[$pid_num]=$instances
            pid_watches[$pid_num]=$watches
            total_instances=$((total_instances + instances))
            total_watches=$((total_watches + watches))
        fi
    done

    # Per-process breakdown sorted by instance count
    echo "Top Consumers (sorted by instances):"
    printf "%-8s %-6s %-40s %10s %10s\n" "USER" "PID" "COMMAND" "INSTANCES" "WATCHES"
    printf "%s\n" "$(printf '%.0s-' {1..80})"

    # Sort PIDs by instance count
    for pid_num in "${!pid_instances[@]}"; do
        printf "%s %s\n" "${pid_instances[$pid_num]}" "$pid_num"
    done | sort -rn | while read count pid_num; do
        local user cmd
        user=$(ps -o user= -p "$pid_num" 2>/dev/null || echo "?")
        cmd=$(ps -o comm= -p "$pid_num" 2>/dev/null || echo "?")

        printf "%-8s %-6s %-40s %'10d %'10d\n" \
            "$user" "$pid_num" "$cmd" \
            "${pid_instances[$pid_num]}" "${pid_watches[$pid_num]}"
    done

    echo
    # Display limits with current usage
    echo "Limits:"

    printf "  max_user_watches:    %'d / %'d" "$total_watches" "$max_watches"
    if [[ "$max_watches" != "N/A" ]] && [[ $max_watches -gt 0 ]]; then
        local watch_percent=$((total_watches * 100 / max_watches))
        printf " (%d%%)" "$watch_percent"
        [[ $watch_percent -gt 80 ]] && printf " ⚠️"
    fi
    echo

    printf "  max_user_instances:  %'d / %'d" "$total_instances" "$max_instances"
    if [[ "$max_instances" != "N/A" ]] && [[ $max_instances -gt 0 ]]; then
        local inst_percent=$((total_instances * 100 / max_instances))
        printf " (%d%%)" "$inst_percent"
        [[ $inst_percent -gt 80 ]] && printf " ⚠️"
    fi
    echo

    printf "  max_queued_events:   N/A / %'d\n" "$max_queued"
    echo
}

main() {
  inotify_usage
}

main "${@}"
