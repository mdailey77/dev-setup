#!/usr/bin/env bash
set -euo pipefail

GLOBAL_HOOKS_DIR="$HOME/.config/git/hooks"
SETUP_DIR="$HOME/.config/devops-vscode-profile"

current_hooks_path="$(git config --global --get core.hooksPath || true)"

if [[ "$current_hooks_path" == "$GLOBAL_HOOKS_DIR" ]]; then
  echo "Removing global Git hooks path..."
  git config --global --unset core.hooksPath
fi

if [[ -f "$GLOBAL_HOOKS_DIR/pre-commit" ]]; then
  echo "Removing global pre-commit hook..."
  rm -f "$GLOBAL_HOOKS_DIR/pre-commit"
fi

if [[ -d "$SETUP_DIR" ]]; then
  echo "Removing installed setup directory..."
  rm -rf "$SETUP_DIR"
fi

echo "Uninstall complete. VS Code extensions and CLI tools were not removed."
