#!/usr/bin/env bash
set -euo pipefail

mkdir -p vscode git/hooks lint

echo "Backing up VS Code extensions..."
if command -v code >/dev/null 2>&1; then
	code --list-extensions >vscode/extensions.txt
else
	echo "WARNING: VS Code CLI 'code' not found. Skipping extension backup."
fi

OS="$(uname -s)"

case "$OS" in
Darwin)
	VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
	;;
Linux)
	VSCODE_USER_DIR="$HOME/.config/Code/User"
	;;
*)
	echo "Unsupported OS: $OS"
	exit 1
	;;
esac

echo "Backing up VS Code settings..."
if [[ -f "$VSCODE_USER_DIR/settings.json" ]]; then
	cp "$VSCODE_USER_DIR/settings.json" vscode/settings.json
fi

if [[ -f "$VSCODE_USER_DIR/keybindings.json" ]]; then
	cp "$VSCODE_USER_DIR/keybindings.json" vscode/keybindings.json
fi

echo "Backing up global Git pre-commit hook if present..."
GLOBAL_HOOKS_PATH="$(git config --global --get core.hooksPath || true)"

if [[ -n "$GLOBAL_HOOKS_PATH" && -f "$GLOBAL_HOOKS_PATH/pre-commit" ]]; then
	cp "$GLOBAL_HOOKS_PATH/pre-commit" git/hooks/pre-commit
fi

echo "Backup complete. Review changes with: git diff"
