#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"

case "$OS" in
  Darwin)
    exec ./scripts/install-macos.sh
    ;;
  Linux)
    exec ./scripts/install-linux.sh
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac
