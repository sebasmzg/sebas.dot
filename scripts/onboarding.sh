#!/usr/bin/env bash
set -euo pipefail

MODE="safe"
REPO_URL="https://github.com/sebasmzg/sebas.dot.git"
TARGET="$HOME/.sebas.dot"
SKIP_CLONE=0

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sebas.dot"
ONBOARDING_LOG="$STATE_DIR/onboarding.log"
INSTALL_LOG="$STATE_DIR/install.log"

usage() {
  cat <<'EOF'
Usage: scripts/onboarding.sh [options]

Options:
  --mode <safe|strict>      Onboarding mode (default: safe)
  --repo <ssh-or-https-url> Repository URL (default: git@github.com:sebasmzg/sebas.dot.git)
  --target <path>           Clone/update target path (default: $HOME/.sebas.dot)
  --skip-clone              Assume repo already exists at target
  --help                    Show this help

Modes:
  safe    Runs install with --no-delete-opencode in real execution
  strict  Runs install without --no-delete-opencode in real execution
EOF
}

log() {
  local level="$1"
  local msg="$2"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$STATE_DIR"
  touch "$ONBOARDING_LOG"
  printf '[onboarding] [%s] %s\n' "$level" "$msg"
  printf '%s [onboarding] [%s] %s\n' "$ts" "$level" "$msg" >>"$ONBOARDING_LOG"
}

fail() {
  log "ERROR" "$1"
  exit 1
}

expand_home_path() {
  local raw="$1"
  if [ "$raw" = "~" ]; then
    printf '%s\n' "$HOME"
    return
  fi

  case "$raw" in
    ~/*)
      printf '%s\n' "$HOME/${raw#~/}"
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
}

command_to_string() {
  local arg
  local rendered=()
  for arg in "$@"; do
    rendered+=("$(printf '%q' "$arg")")
  done
  printf '%s' "${rendered[*]}"
}

run_cmd() {
  local rendered
  rendered="$(command_to_string "$@")"
  log "INFO" "RUN: $rendered"
  "$@"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode)
        shift
        [ "$#" -gt 0 ] || fail "--mode requires a value"
        case "$1" in
          safe|strict)
            MODE="$1"
            ;;
          *)
            fail "invalid mode: $1 (allowed: safe, strict)"
            ;;
        esac
        ;;
      --repo)
        shift
        [ "$#" -gt 0 ] || fail "--repo requires a value"
        REPO_URL="$1"
        ;;
      --target)
        shift
        [ "$#" -gt 0 ] || fail "--target requires a value"
        TARGET="$1"
        ;;
      --skip-clone)
        SKIP_CLONE=1
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        fail "unknown option: $1"
        ;;
    esac
    shift
  done
}

check_required_commands() {
  local missing=()
  local cmd
  for cmd in git curl rsync bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    fail "missing required commands: ${missing[*]}"
  fi

  log "INFO" "Required commands available: git curl rsync bash"
}

check_repo_connectivity() {
  log "INFO" "Checking repository reachability with git ls-remote"
  if ! git ls-remote --heads "$REPO_URL" >/dev/null 2>&1; then
    fail "cannot reach repository: $REPO_URL"
  fi
  log "INFO" "Repository reachable: $REPO_URL"
}

detect_ssh_auth_non_fatal() {
  case "$REPO_URL" in
    git@*:*|ssh://*)
      ;;
    *)
      return
      ;;
  esac

  if ! command -v ssh >/dev/null 2>&1; then
    log "WARN" "SSH URL detected but ssh command not found; skipping SSH auth hint"
    return
  fi

  local host
  if [[ "$REPO_URL" == git@*:* ]]; then
    host="${REPO_URL#git@}"
    host="${host%%:*}"
  else
    host="${REPO_URL#ssh://}"
    host="${host#*@}"
    host="${host%%/*}"
    host="${host%%:*}"
  fi

  log "INFO" "SSH URL detected, checking auth hint for git@$host"

  local ssh_out
  ssh_out="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -T "git@$host" 2>&1 || true)"

  case "$ssh_out" in
    *"successfully authenticated"*|*"You've successfully authenticated"*)
      log "INFO" "SSH authentication looks configured for git@$host"
      ;;
    *)
      log "WARN" "SSH auth check was inconclusive for git@$host (non-fatal)"
      ;;
  esac
}

preflight() {
  log "INFO" "Starting preflight"
  check_required_commands
  check_repo_connectivity
  detect_ssh_auth_non_fatal
  log "INFO" "Preflight completed"
}

ensure_repo_ready() {
  TARGET="$(expand_home_path "$TARGET")"

  if [[ "$TARGET" == *"~"* ]]; then
    fail "invalid target path after normalization: '$TARGET' contains literal '~'. Use an absolute path or '~/...'."
  fi

  if [ "$SKIP_CLONE" -eq 1 ]; then
    log "INFO" "--skip-clone enabled; validating existing repository"
    [ -d "$TARGET" ] || fail "target does not exist with --skip-clone: $TARGET"
    git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "target is not a git repository: $TARGET"
    [ -f "$TARGET/scripts/install.sh" ] || fail "missing install script at: $TARGET/scripts/install.sh"
    log "INFO" "Using existing repository at $TARGET"
    return
  fi

  if [ -d "$TARGET/.git" ] && git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "INFO" "Existing git repository found at $TARGET; pulling fast-forward only"
    run_cmd git -C "$TARGET" pull --ff-only
    return
  fi

  if [ -e "$TARGET" ] && [ ! -d "$TARGET/.git" ]; then
    fail "target exists but is not a git repository: $TARGET"
  fi

  if [ -d "$TARGET" ]; then
    fail "target directory exists without valid .git metadata: $TARGET"
  fi

  local parent_dir
  parent_dir="$(dirname "$TARGET")"
  run_cmd mkdir -p "$parent_dir"
  log "INFO" "Cloning repository into $TARGET"
  run_cmd git clone "$REPO_URL" "$TARGET"
}

run_install_dry_run() {
  log "INFO" "Running install dry-run"
  run_cmd bash "$TARGET/scripts/install.sh" --dry-run
}

run_install_real() {
  if [ "$MODE" = "safe" ]; then
    log "INFO" "Running real install in SAFE mode"
    run_cmd bash "$TARGET/scripts/install.sh" --no-delete-opencode
    return
  fi

  log "INFO" "Running real install in STRICT mode"
  run_cmd bash "$TARGET/scripts/install.sh"
}

print_final_summary() {
  log "INFO" "Onboarding finished"
  printf '\n'
  printf 'Onboarding summary\n'
  printf '  mode: %s\n' "$MODE"
  printf '  repo: %s\n' "$REPO_URL"
  printf '  target: %s\n' "$TARGET"
  printf '  install log: %s\n' "$INSTALL_LOG"
  printf '  onboarding log: %s\n' "$ONBOARDING_LOG"
}

main() {
  parse_args "$@"
  preflight
  ensure_repo_ready
  run_install_dry_run
  run_install_real
  print_final_summary
}

main "$@"
