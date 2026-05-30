#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="$HOME/Library/Logs/homebrew-weekly"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/update-$(date '+%Y-%m-%d_%H-%M-%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

notify() {
	local message="$1"
	if command -v osascript >/dev/null 2>&1; then
		osascript -e "display notification \"${message}\" with title \"Mac app updates\"" || true
	fi
}

on_error() {
	local exit_code=$?
	echo
	echo "ERROR: Weekly Homebrew update failed with exit code ${exit_code}."
	echo "Log file: ${LOG_FILE}"
	notify "Weekly Homebrew update failed. Check logs."
	exit "${exit_code}"
}
trap on_error ERR

echo "===== Weekly Homebrew update started: $(date) ====="

if [[ -x /opt/homebrew/bin/brew ]]; then
	BREW="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
	BREW="/usr/local/bin/brew"
else
	echo "ERROR: Homebrew not found. Install Homebrew first: https://brew.sh"
	exit 1
fi

echo "Using Homebrew at: ${BREW}"
"${BREW}" --version

echo
echo "Updating Homebrew metadata..."
"${BREW}" update

echo
echo "Upgrading Homebrew formulae..."
"${BREW}" upgrade

echo
echo "Upgrading GUI applications except privileged/problematic casks..."

# Docker Desktop can require sudo to remove or replace privileged helper tools:
#   /Library/PrivilegedHelperTools/com.docker.*
#
# A launchd user agent cannot interactively enter your sudo password, so Docker
# Desktop should be updated manually from Terminal when needed.
SKIP_CASKS=(
	"docker"
	"docker-desktop"
)

is_skipped_cask() {
	local cask="$1"

	for skipped in "${SKIP_CASKS[@]}"; do
		if [[ "$cask" == "$skipped" ]]; then
			return 0
		fi
	done

	return 1
}

while IFS= read -r cask; do
	if is_skipped_cask "$cask"; then
		echo "Skipping cask: $cask"
		echo "Reason: may require sudo or privileged helper changes during upgrade."
		continue
	fi

	echo
	echo "Upgrading cask: $cask"

	if ! "${BREW}" upgrade --cask "$cask" --greedy-auto-updates; then
		echo "WARNING: Failed to upgrade cask: $cask"
		echo "Continuing with remaining casks..."
	fi
done < <("${BREW}" list --cask)

echo
echo "Cleaning up old versions..."
"${BREW}" cleanup

echo
echo "Checking Homebrew health..."
"${BREW}" doctor || true

osascript -e 'display notification "Weekly Homebrew update completed." with title "Mac app updates"' || true

echo
echo "===== Weekly Homebrew update finished: $(date) ====="
echo "Log file: $LOG_FILE"
