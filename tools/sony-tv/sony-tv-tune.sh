#!/usr/bin/env bash
# Debloat and speed up a Sony Bravia Android TV / Google TV over ADB.
# Removes packages for user 0 only (no root, survives as "disabled" until factory reset)
# so everything here is reversible with `restore`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="${SCRIPT_DIR}/packages.txt"
LOG_FILE="${SCRIPT_DIR}/removed-packages.log"
ANIM_SCALE="0.5"
DRY_RUN=0
AGGRESSIVE=0
TV_ADDR=""

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options] <command>

Commands:
  audit      List installed packages to installed-packages.txt (read only)
  debloat    Remove packages in packages.txt for user 0
  speed      Shorter animations, clear caches, recompile apps
  all        debloat + speed
  restore    Reinstall every package in removed-packages.log

Options:
  -t, --tv IP[:PORT]   Connect to TV over network ADB first (default port 5555)
  -a, --aggressive     Also remove packages marked "?" in packages.txt
  -s, --anim SCALE     Animation scale for speed (default 0.5, 0 = off)
  -n, --dry-run        Print adb commands, change nothing
  -h, --help           Show this help

Exit codes: 0 ok, 1 usage error, 2 adb missing or no device, 3 partial failure
USAGE
}

die() { echo "error: $1" >&2; exit "${2:-1}"; }

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] adb $*"
  else
    adb "$@"
  fi
}

require_device() {
  command -v adb >/dev/null || die "adb not found. Install Android platform-tools." 2
  if [[ -n "$TV_ADDR" ]]; then
    [[ "$TV_ADDR" == *:* ]] || TV_ADDR="${TV_ADDR}:5555"
    adb connect "$TV_ADDR" >/dev/null
  fi
  local state
  state="$(adb get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || die "no authorized device. Accept the USB debugging prompt on the TV." 2
}

installed_packages() {
  adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort
}

cmd_audit() {
  local out="${SCRIPT_DIR}/installed-packages.txt"
  installed_packages > "$out"
  echo "wrote $(wc -l < "$out") packages to $out"
  grep -E '^com\.sony\.' "$out" | sed 's/^/  sony: /' || true
}

wanted_packages() {
  local line
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    if [[ "$line" == \?* ]]; then
      [[ $AGGRESSIVE -eq 1 ]] && echo "${line#\?}"
    else
      echo "$line"
    fi
  done < "$PKG_FILE"
}

cmd_debloat() {
  local installed failures=0 pkg
  installed="$(installed_packages)"
  while IFS= read -r pkg; do
    if ! grep -qxF "$pkg" <<<"$installed"; then
      echo "skip   $pkg (not installed)"
      continue
    fi
    echo "remove $pkg"
    # pm can print "Failure [...]" yet exit 0 on some Bravia builds, so check the text.
    if [[ $DRY_RUN -eq 1 ]]; then
      run shell pm uninstall -k --user 0 "$pkg"
    elif adb shell pm uninstall -k --user 0 "$pkg" | grep -q '^Success'; then
      echo "$pkg" >> "$LOG_FILE"
    else
      echo "  failed: $pkg" >&2
      failures=$((failures + 1))
    fi
  done < <(wanted_packages)
  return $(( failures > 0 ? 3 : 0 ))
}

cmd_speed() {
  local key
  for key in window_animation_scale transition_animation_scale animator_duration_scale; do
    run shell settings put global "$key" "$ANIM_SCALE"
  done
  # Frees flash; Bravia models with 8-16 GB storage slow down badly when near full.
  run shell pm trim-caches 999G
  # AOT-compile apps now instead of waiting for the idle maintenance job.
  echo "recompiling apps (can take 5-15 min)..."
  run shell cmd package bg-dexopt-job
}

cmd_restore() {
  [[ -f "$LOG_FILE" ]] || die "no $LOG_FILE, nothing to restore" 1
  local failures=0 pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "restore $pkg"
    run shell cmd package install-existing "$pkg" || failures=$((failures + 1))
  done < <(sort -u "$LOG_FILE")
  [[ $DRY_RUN -eq 1 || $failures -gt 0 ]] || rm -f "$LOG_FILE"
  return $(( failures > 0 ? 3 : 0 ))
}

main() {
  local command=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--tv) TV_ADDR="${2:?--tv needs an address}"; shift 2 ;;
      -a|--aggressive) AGGRESSIVE=1; shift ;;
      -s|--anim) ANIM_SCALE="${2:?--anim needs a value}"; shift 2 ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      audit|debloat|speed|all|restore) command="$1"; shift ;;
      *) usage >&2; exit 1 ;;
    esac
  done
  [[ -n "$command" ]] || { usage >&2; exit 1; }
  [[ "$ANIM_SCALE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "--anim must be a number" 1

  require_device
  case "$command" in
    audit) cmd_audit ;;
    debloat) cmd_debloat ;;
    speed) cmd_speed ;;
    all) local rc=0; cmd_debloat || rc=$?; cmd_speed; exit "$rc" ;;
    restore) cmd_restore ;;
  esac
}

main "$@"
