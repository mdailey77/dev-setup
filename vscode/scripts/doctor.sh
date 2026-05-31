#!/usr/bin/env bash
set -euo pipefail

missing=0

check_command() {
	local cmd="$1"
	if command -v "$cmd" >/dev/null 2>&1; then
		printf 'OK   %s\n' "$cmd"
	else
		printf 'MISS %s\n' "$cmd"
		missing=$((missing + 1))
	fi
}

check_file() {
	local file="$1"
	if [[ -e "$file" ]]; then
		printf 'OK   %s\n' "$file"
	else
		printf 'MISS %s\n' "$file"
		missing=$((missing + 1))
	fi
}

echo "Checking required commands..."
for cmd in git code yq shellcheck yamllint terraform tflint jsonlint gitleaks kubectl helm kubeconform hadolint ansible-lint markdownlint-cli2 glab; do
	check_command "$cmd"
done

echo
echo "Checking installed files..."
check_file "$HOME/.config/devops-vscode-profile/lint/lint-staged-devops.sh"
check_file "$HOME/.config/git/hooks/pre-commit"

echo
echo "Checking Git global hooks path..."
configured_hooks_path="$(git config --global --get core.hooksPath || true)"
expected_hooks_path="$HOME/.config/git/hooks"

if [[ "$configured_hooks_path" == "$expected_hooks_path" ]]; then
	echo "OK   core.hooksPath=$configured_hooks_path"
else
	echo "MISS core.hooksPath expected $expected_hooks_path but found ${configured_hooks_path:-unset}"
	missing=$((missing + 1))
fi

echo
if [[ "$missing" -gt 0 ]]; then
	echo "Doctor found $missing missing or misconfigured item(s)."
	exit 1
fi

echo "Doctor checks passed."
