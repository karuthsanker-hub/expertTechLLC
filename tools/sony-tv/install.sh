#!/usr/bin/env bash
# Installs adb (Android platform-tools) on macOS or Linux so sony-tv-tune.sh can run.
# Prefers the OS package manager; falls back to Google's official zip in ~/.local.
set -euo pipefail

PT_DIR="${HOME}/.local/platform-tools"
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [-n|--dry-run] [-h|--help]

Installs adb if missing: Homebrew on macOS, apt/dnf on Linux,
otherwise Google's platform-tools zip into ${PT_DIR}.

Exit codes: 0 ok, 1 usage error, 2 install failed
USAGE
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then echo "[dry-run] $*"; else "$@"; fi
}

install_from_zip() {
  local os="$1" tmp
  tmp="$(mktemp -d)"
  run curl -fsSL -o "${tmp}/pt.zip" "https://dl.google.com/android/repository/platform-tools-latest-${os}.zip"
  run mkdir -p "${HOME}/.local"
  run rm -rf "$PT_DIR"
  run unzip -q "${tmp}/pt.zip" -d "${HOME}/.local"
  echo "add to your shell profile:  export PATH=\"${PT_DIR}:\$PATH\""
  export PATH="${PT_DIR}:${PATH}"
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    "") ;;
    *) usage >&2; exit 1 ;;
  esac

  if command -v adb >/dev/null; then
    echo "adb already installed: $(command -v adb)"
    exit 0
  fi

  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null; then
        run brew install --cask android-platform-tools
      else
        install_from_zip darwin
      fi ;;
    Linux)
      if command -v apt-get >/dev/null; then
        run sudo apt-get install -y adb
      elif command -v dnf >/dev/null; then
        run sudo dnf install -y android-tools
      else
        install_from_zip linux
      fi ;;
    *) echo "unsupported OS: use the Windows steps in README.md" >&2; exit 2 ;;
  esac

  [[ $DRY_RUN -eq 1 ]] && exit 0
  command -v adb >/dev/null || { echo "adb still not on PATH" >&2; exit 2; }
  adb version | head -1
}

main "$@"
