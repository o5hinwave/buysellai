#!/usr/bin/env bash
set -euo pipefail

if command -v rg >/dev/null 2>&1; then
  printf 'ripgrep: %s\n' "$(rg --version | head -n 1)"
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      printf 'error: ripgrep is missing and Homebrew is not available\n' >&2
      exit 1
    fi

    if brew tap --list | grep -qx 'aws/tap'; then
      brew untap aws/tap || true
    fi

    brew install ripgrep
    ;;
  Linux)
    sudo apt-get update
    sudo apt-get install -y ripgrep
    ;;
  *)
    printf 'error: ripgrep is missing on unsupported platform %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac

printf 'ripgrep: %s\n' "$(rg --version | head -n 1)"
