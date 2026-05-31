#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP_DIR="$HOME/.config/devops-vscode-profile"
VSCODE_USER_DIR="$HOME/.config/Code/User"
GLOBAL_HOOKS_DIR="$HOME/.config/git/hooks"

mkdir -p "$SETUP_DIR"
mkdir -p "$VSCODE_USER_DIR"
mkdir -p "$GLOBAL_HOOKS_DIR"

echo "Copying setup files to $SETUP_DIR..."
rsync -a --delete \
	--exclude '.git/' \
	"$SOURCE_DIR/" "$SETUP_DIR/"

echo "Installing VS Code extensions..."
if command -v code >/dev/null 2>&1; then
	while IFS= read -r extension; do
		[[ -z "$extension" || "$extension" =~ ^# ]] && continue
		code --install-extension "$extension"
	done <"$SETUP_DIR/vscode/extensions.txt"
else
	echo "WARNING: VS Code CLI 'code' not found."
fi

echo "Installing VS Code user settings..."
cp "$SETUP_DIR/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"

if [[ -f "$SETUP_DIR/vscode/keybindings.json" ]]; then
	cp "$SETUP_DIR/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
fi

echo "Installing global Git hook..."
cp "$SETUP_DIR/git/hooks/pre-commit" "$GLOBAL_HOOKS_DIR/pre-commit"
chmod +x "$GLOBAL_HOOKS_DIR/pre-commit"
chmod +x "$SETUP_DIR/lint/lint-staged-devops.sh"

git config --global core.hooksPath "$GLOBAL_HOOKS_DIR"

echo "Configuring useful global Git defaults..."
git config --global fetch.prune true
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor "code --wait"

cat <<'MSG'

Linux setup files were installed.

This script does not install all CLI linting tools because Linux package managers vary by distribution.
Install these tools with your preferred package manager:

  git jq yq shellcheck yamllint terraform tflint gitleaks kubectl helm kubeconform hadolint ansible-lint markdownlint-cli2 glab

Then run:

  ./scripts/doctor.sh
MSG
