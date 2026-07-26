#!/usr/bin/env bash
set -euo pipefail

if command -v rg >/dev/null 2>&1; then
  printf 'ripgrep: %s\n' "$(rg --version | head -n 1)"
  exit 0
fi

case "$(uname -s)" in
  Darwin)
    version="${RIPGREP_VERSION:-15.2.0}"
    machine="$(uname -m)"
    case "$machine" in
      arm64)
        arch="aarch64"
        ;;
      x86_64)
        arch="x86_64"
        ;;
      *)
        printf 'error: ripgrep is missing on unsupported macOS architecture %s\n' "$machine" >&2
        exit 1
        ;;
    esac

    archive="ripgrep-${version}-${arch}-apple-darwin.tar.gz"
    temp_dir="$(mktemp -d)"
    install_dir="${RUNNER_TEMP:-/tmp}/buysell-scan-tools/bin"
    mkdir -p "$install_dir"

    curl -fsSL \
      "https://github.com/BurntSushi/ripgrep/releases/download/${version}/${archive}" \
      -o "${temp_dir}/${archive}"
    LC_ALL=C tar -xzf "${temp_dir}/${archive}" -C "$temp_dir"
    install -m 0755 "${temp_dir}/ripgrep-${version}-${arch}-apple-darwin/rg" "${install_dir}/rg"
    rm -rf "$temp_dir"

    export PATH="${install_dir}:$PATH"
    if [[ -n "${GITHUB_PATH:-}" ]]; then
      printf '%s\n' "$install_dir" >> "$GITHUB_PATH"
    fi
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
