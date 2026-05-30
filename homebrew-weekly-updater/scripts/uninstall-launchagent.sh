#!/usr/bin/env bash
set -Eeuo pipefail

LABEL="com.local.weekly-homebrew-update"
PLIST_TARGET="$HOME/Library/LaunchAgents/${LABEL}.plist"
SCRIPT_TARGET="$HOME/bin/weekly-brew-update.sh"

launchctl bootout "gui/$(id -u)" "$PLIST_TARGET" 2>/dev/null || true
rm -f "$PLIST_TARGET"

read -r -p "Remove updater script at ${SCRIPT_TARGET}? [y/N] " answer
case "$answer" in
  [Yy]*) rm -f "$SCRIPT_TARGET" ;;
  *) echo "Keeping script: ${SCRIPT_TARGET}" ;;
esac

echo "Uninstalled ${LABEL}."
