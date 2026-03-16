#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE_PATH="$REPO_ROOT/Brewfile"
BREWFILE_LINUX_PATH="$REPO_ROOT/Brewfile.linux"
SELECTED_BREWFILE_PATH="$BREWFILE_PATH"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sebas.dot"
LOG_FILE="$STATE_DIR/install.log"

DRY_RUN=0
NO_DELETE_OPENCODE=0
ONLY_PHASE=""
SHOW_HELP=0

log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[sebas.dot] %s\n' "$msg"
  if [ -n "${LOG_FILE:-}" ]; then
    printf '%s [sebas.dot] %s\n' "$ts" "$msg" >>"$LOG_FILE"
  fi
}

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Options:
  --dry-run               Show actions without executing changes
  --no-delete-opencode    Sync opencode without rsync --delete
  --only <brew|links|opencode>
                          Run only one phase
  --help                  Show this help
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      --no-delete-opencode)
        NO_DELETE_OPENCODE=1
        ;;
      --only)
        shift
        if [ "$#" -eq 0 ]; then
          printf 'ERROR: --only requires a value\n' >&2
          exit 1
        fi
        case "$1" in
          brew|links|opencode)
            ONLY_PHASE="$1"
            ;;
          *)
            printf 'ERROR: invalid --only value: %s\n' "$1" >&2
            exit 1
            ;;
        esac
        ;;
      --help)
        SHOW_HELP=1
        ;;
      *)
        printf 'ERROR: unknown option: %s\n' "$1" >&2
        exit 1
        ;;
    esac
    shift
  done
}

command_to_string() {
  local arg
  local parts=()
  for arg in "$@"; do
    parts+=("$(printf '%q' "$arg")")
  done
  printf '%s' "${parts[*]}"
}

run_cmd() {
  local rendered
  rendered="$(command_to_string "$@")"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: $rendered"
    return 0
  fi

  log "RUN: $rendered"
  "$@"
}

run_script_cmd() {
  local script="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: /bin/bash -c <bootstrap script>"
    return 0
  fi

  log "RUN: /bin/bash -c <bootstrap script>"
  /bin/bash -c "$script"
}

init_logging() {
  mkdir -p "$STATE_DIR"
  touch "$LOG_FILE"
}

backup_path() {
  local target="$1"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"
  run_cmd mv "$target" "${target}.pre-sebasdot-backup-${stamp}"
}

safe_symlink() {
  local source="$1"
  local target="$2"

  run_cmd mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      log "Symlink already OK: $target"
      return
    fi
    run_cmd rm "$target"
  elif [ -e "$target" ]; then
    log "Backing up existing target: $target"
    backup_path "$target"
  fi

  run_cmd ln -s "$source" "$target"
  log "Linked $target -> $source"
}

ensure_linuxbrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already available"
    return
  fi

  log "Homebrew not found. Starting Linuxbrew bootstrap"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: would fetch and execute Homebrew installer"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log "ERROR: curl is required to bootstrap Homebrew"
    exit 1
  fi

  log "Fetching installer from Homebrew official URL"
  local installer
  installer="$(curl -fL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  run_script_cmd "NONINTERACTIVE=1 $installer"

  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    log "Loading brew shellenv from /home/linuxbrew/.linuxbrew/bin/brew"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    log "Loading brew shellenv from $HOME/.linuxbrew/bin/brew"
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || {
    log "ERROR: brew not available after installation"
    exit 1
  }
}

select_brewfile() {
  local os
  os="$(uname -s)"

  if [ "$os" = "Linux" ]; then
    if [ -f "$BREWFILE_LINUX_PATH" ]; then
      SELECTED_BREWFILE_PATH="$BREWFILE_LINUX_PATH"
      log "Linux detected. Using Linux-only Brewfile: $SELECTED_BREWFILE_PATH"
      return
    fi

    SELECTED_BREWFILE_PATH="$BREWFILE_PATH"
    log "WARNING: Linux detected but $BREWFILE_LINUX_PATH not found; falling back to $SELECTED_BREWFILE_PATH"
    return
  fi

  SELECTED_BREWFILE_PATH="$BREWFILE_PATH"
  log "OS detected: $os. Using default Brewfile: $SELECTED_BREWFILE_PATH"
}

apply_brewfile() {
  select_brewfile
  log "Applying Brewfile: $SELECTED_BREWFILE_PATH"
  run_cmd brew bundle --file "$SELECTED_BREWFILE_PATH"
}

link_core_configs() {
  log "Creating safe symlinks for core dotfiles"
  safe_symlink "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
  safe_symlink "$REPO_ROOT/.p10k.zsh" "$HOME/.p10k.zsh"

  safe_symlink "$REPO_ROOT/.config/atuin" "$HOME/.config/atuin"
  safe_symlink "$REPO_ROOT/.config/ghostty" "$HOME/.config/ghostty"
  safe_symlink "$REPO_ROOT/.config/nvim" "$HOME/.config/nvim"
  safe_symlink "$REPO_ROOT/.config/zellij" "$HOME/.config/zellij"
}

opencode_base_phase() {
  log "Opencode phase 1/2: generic base setup"
  run_cmd mkdir -p "$HOME/.config/opencode"
  if command -v opencode >/dev/null 2>&1; then
    log "Opencode CLI detected"
  else
    log "Opencode CLI not found in PATH (continuing with config sync)"
  fi
}

opencode_sync_phase() {
  log "Opencode phase 2/2: syncing config and skills"
  local -a rsync_args
  rsync_args=(-a)

  if [ "$NO_DELETE_OPENCODE" -eq 0 ]; then
    rsync_args+=(--delete)
  else
    log "Skipping rsync --delete for opencode sync"
  fi

  rsync_args+=(
    --exclude 'node_modules/'
    --exclude '*.bak'
    --exclude '.env'
    --exclude '.env.*'
    --exclude 'secrets/'
    "$REPO_ROOT/.config/opencode/"
    "$HOME/.config/opencode/"
  )

  run_cmd rsync "${rsync_args[@]}"
}

run_brew_phase() {
  ensure_linuxbrew
  apply_brewfile
}

run_links_phase() {
  link_core_configs
}

run_opencode_phase() {
  opencode_base_phase
  opencode_sync_phase
}

main() {
  parse_args "$@"

  if [ "$SHOW_HELP" -eq 1 ]; then
    usage
    exit 0
  fi

  init_logging
  log "Starting installer"
  log "Options: dry_run=$DRY_RUN no_delete_opencode=$NO_DELETE_OPENCODE only=${ONLY_PHASE:-all}"

  case "$ONLY_PHASE" in
    "")
      run_brew_phase
      run_links_phase
      run_opencode_phase
      ;;
    brew)
      run_brew_phase
      ;;
    links)
      run_links_phase
      ;;
    opencode)
      run_opencode_phase
      ;;
  esac

  log "Done"
}

main "$@"
