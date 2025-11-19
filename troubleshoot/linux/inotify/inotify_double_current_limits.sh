#!/usr/bin/env bash
set -euo pipefail

# Double current inotify limits and save to /etc/sysctl.d/99-inotify.conf

main() {
  # Get current values
  max_watches=$(sysctl -n fs.inotify.max_user_watches)
  max_instances=$(sysctl -n fs.inotify.max_user_instances)
  max_events=$(sysctl -n fs.inotify.max_queued_events)

  # Double them
  new_watches=$((max_watches * 2))
  new_instances=$((max_instances * 2))
  new_events=$((max_events * 2))

  # Show what we're doing
  echo "### Limits: [current] -> [upcoming]:"
  echo "  max_user_watches:    $max_watches -> $new_watches"
  echo "  max_user_instances:  $max_instances -> $new_instances"
  echo "  max_queued_events:   $max_events -> $new_events"
  echo

  echo "We are about to ask for [sudo] as we are going to modify the inotify system configuration."
  echo "Remember to [Review Scripts from Internet Prior to Running Them](https://notes.thorg.app/notes/rqpzs1z92lkzz79d8pjltdj). Especially that this script is asking for sudo access."
  echo "The script you are running can be found at:"
  echo "https://raw.githubusercontent.com/Thorg-App/script/refs/heads/main/troubleshoot/linux/inotify/inotify_double_current_limits.sh"
  echo ""

  # Write and apply config inline with sudo
  local CONFIG_FILE="/etc/sysctl.d/99-inotify.conf"

  echo "Writing to $CONFIG_FILE..."
  sudo tee "$CONFIG_FILE" > /dev/null <<EOF
# Inotify limits for file watching (doubled on $(date +%Y-%m-%d))
fs.inotify.max_user_watches = $new_watches
fs.inotify.max_user_instances = $new_instances
fs.inotify.max_queued_events = $new_events
EOF

  # Apply changes
  echo "Applying changes..."
  sudo sysctl -p "$CONFIG_FILE"

  # Verify
  echo
  echo "Verification:"
  sysctl fs.inotify.max_user_watches
  sysctl fs.inotify.max_user_instances
  sysctl fs.inotify.max_queued_events
}

main "${@}"