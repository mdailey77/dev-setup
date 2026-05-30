#!/usr/bin/env bash
set -Eeuo pipefail

LABEL="com.local.weekly-homebrew-update"
SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_SOURCE_DIR}/.." && pwd)"
SCRIPT_SOURCE="${PROJECT_DIR}/scripts/weekly-brew-update.sh"
SCRIPT_TARGET="$HOME/bin/weekly-brew-update.sh"
PLIST_TARGET="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/homebrew-weekly"

mkdir -p "$HOME/bin" "$HOME/Library/LaunchAgents" "$LOG_DIR"
cp "$SCRIPT_SOURCE" "$SCRIPT_TARGET"
chmod +x "$SCRIPT_TARGET"

cat > "$PLIST_TARGET" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${SCRIPT_TARGET}</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>${LOG_DIR}/launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/launchd.err.log</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST_TARGET" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_TARGET"
launchctl enable "gui/$(id -u)/${LABEL}"

echo "Installed ${LABEL}."
echo "Script: ${SCRIPT_TARGET}"
echo "LaunchAgent: ${PLIST_TARGET}"
echo "Runs weekly: Monday at 09:00 local time."
echo
echo "Test manually with:"
echo "  launchctl kickstart -k gui/$(id -u)/${LABEL}"
echo
echo "View logs with:"
echo "  tail -n 100 ${LOG_DIR}/launchd.out.log"
echo "  tail -n 100 ${LOG_DIR}/launchd.err.log"
