#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE_PATH="$REPO_ROOT/Brewfile"
BREWFILE_LINUX_PATH="$REPO_ROOT/Brewfile.linux"
SELECTED_BREWFILE_PATH="$BREWFILE_PATH"
CLAUDE_NPM_PACKAGE="@anthropic-ai/claude-code"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sebas.dot"
LOG_FILE="$STATE_DIR/install.log"

DRY_RUN=0
NO_DELETE_OPENCODE=0
ONLY_PHASE=""
SHOW_HELP=0
PHASE_WARNINGS=0
PHASE_ERRORS=0

log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[sebas.dot] %s\n' "$msg"
  if [ -n "${LOG_FILE:-}" ]; then
    printf '%s [sebas.dot] %s\n' "$ts" "$msg" >>"$LOG_FILE"
  fi
}

warn() {
  log "WARNING: $1"
}

err() {
  log "ERROR: $1"
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

on_error() {
  local line_no="$1"
  local exit_code="$2"
  log "ERROR: Installer failed at line $line_no (exit code: $exit_code)"
  log "TROUBLESHOOTING: review $LOG_FILE and rerun with: bash scripts/install.sh --dry-run"
  exit "$exit_code"
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
    err "curl is required to bootstrap Homebrew"
    return 1
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
    err "brew not available after installation"
    return 1
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

print_troubleshooting_hints() {
  log "Troubleshooting hints:"
  log "- Install log: $LOG_FILE"
  log "- Re-run only package installation: bash $REPO_ROOT/scripts/install.sh --only brew"
  log "- Re-run only symlink setup: bash $REPO_ROOT/scripts/install.sh --only links"
  log "- Re-run only opencode sync: bash $REPO_ROOT/scripts/install.sh --only opencode --no-delete-opencode"
}

validate_critical_binaries() {
  local -a required_bins
  local -a missing_bins
  local bin
  local install_hint=""

  required_bins=(brew zsh nvim zellij atuin zoxide git rg fd opencode docker)
  missing_bins=()

  for bin in "${required_bins[@]}"; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      missing_bins+=("$bin")
    fi
  done

  if [ "${#missing_bins[@]}" -eq 0 ]; then
    log "Critical binary check OK: brew zsh nvim zellij atuin zoxide git rg fd opencode docker"
    return
  fi

  for bin in "${missing_bins[@]}"; do
    case "$bin" in
      rg)
        install_hint+=" ripgrep"
        ;;
      *)
        install_hint+=" $bin"
        ;;
    esac
  done

  log "WARNING: Missing critical binaries:${install_hint}"
  log "Run this to install missing binaries: brew install${install_hint}"
}

ensure_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [ -z "$zsh_path" ]; then
    log "WARNING: zsh not found in PATH; cannot set default shell"
    return
  fi

  local current_shell=""
  if command -v getent >/dev/null 2>&1; then
    current_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
  fi

  if [ -z "$current_shell" ]; then
    current_shell="${SHELL:-}"
  fi

  if [ "$current_shell" = "$zsh_path" ]; then
    log "Default shell already set to zsh: $zsh_path"
    return
  fi

  if ! command -v chsh >/dev/null 2>&1; then
    log "WARNING: chsh not available. Set shell manually: chsh -s '$zsh_path'"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: would set default shell to zsh with: chsh -s '$zsh_path'"
    return
  fi

  log "Setting default shell to zsh for user $USER"
  chsh -s "$zsh_path" || log "WARNING: Could not change default shell automatically. Run manually: chsh -s '$zsh_path'"
}

ensure_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code CLI already available"
    return
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log "WARNING: npm not found; skipping Claude Code install"
    log "Install manually with: npm install -g $CLAUDE_NPM_PACKAGE"
    return
  fi

  log "Installing Claude Code CLI from npm package: $CLAUDE_NPM_PACKAGE"
  run_cmd npm install -g "$CLAUDE_NPM_PACKAGE"

  if command -v claude >/dev/null 2>&1; then
    log "Claude Code CLI installation completed"
  else
    log "WARNING: Claude Code CLI still not found in PATH after installation"
  fi
}

verify_shell_integrations() {
  local zshrc_path="$REPO_ROOT/.zshrc"

  if grep -F 'zoxide init zsh' "$zshrc_path" >/dev/null 2>&1; then
    log "Shell integration check OK: zoxide init present"
  else
    log "WARNING: zoxide init missing in $zshrc_path"
  fi

  if grep -F 'atuin init zsh' "$zshrc_path" >/dev/null 2>&1; then
    log "Shell integration check OK: atuin init present"
  else
    log "WARNING: atuin init missing in $zshrc_path"
  fi

  if grep -F "alias zj='zellij'" "$zshrc_path" >/dev/null 2>&1; then
    log "Shell integration check OK: zellij alias present"
  else
    log "WARNING: zellij alias missing in $zshrc_path"
  fi
}

ensure_ghostty_uses_zsh() {
  local ghostty_cfg="$REPO_ROOT/.config/ghostty/config"
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [ -z "$zsh_path" ]; then
    zsh_path="/usr/bin/zsh"
  fi

  if [ ! -f "$ghostty_cfg" ]; then
    log "WARNING: Ghostty config not found at $ghostty_cfg"
    return
  fi

  if grep -E '^command\s*=\s*.+zsh' "$ghostty_cfg" >/dev/null 2>&1; then
    log "Ghostty shell check OK: zsh command already configured"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: would append Ghostty shell command: command = $zsh_path"
    return
  fi

  log "Configuring Ghostty default shell to zsh: $zsh_path"
  printf '\ncommand = %s\n' "$zsh_path" >>"$ghostty_cfg"
}

ensure_zsh_in_etc_shells() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"

  if [ -z "$zsh_path" ]; then
    log "WARNING: zsh not found in PATH; skipping /etc/shells registration"
    return
  fi

  if [ ! -f /etc/shells ]; then
    log "WARNING: /etc/shells not found; cannot register $zsh_path"
    return
  fi

  if grep -Fx "$zsh_path" /etc/shells >/dev/null 2>&1; then
    log "zsh already registered in /etc/shells: $zsh_path"
    return
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: would register zsh in /etc/shells using sudo tee"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    log "Registering zsh in /etc/shells: $zsh_path"
    printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null || {
      log "WARNING: Failed to register zsh in /etc/shells. Run manually: echo '$zsh_path' | sudo tee -a /etc/shells"
      return
    }
  else
    log "WARNING: sudo not available. Register zsh manually: echo '$zsh_path' | sudo tee -a /etc/shells"
    return
  fi

  if command -v chsh >/dev/null 2>&1; then
    log "Attempting to set default shell to zsh for user $USER"
    chsh -s "$zsh_path" || log "WARNING: Could not change default shell automatically. Run manually: chsh -s '$zsh_path'"
  else
    log "WARNING: chsh not available. Set shell manually if needed"
  fi
}

ensure_zsh_runtime_paths() {
  local zsh_data_dir
  zsh_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh"
  local zsh_history_file
  zsh_history_file="$zsh_data_dir/history"

  log "Ensuring zsh runtime paths exist"
  run_cmd mkdir -p "$zsh_data_dir"
  run_cmd touch "$zsh_history_file"
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
  local brew_ready=1
  local brew_bundle_ok=1

  if ! ensure_linuxbrew; then
    brew_ready=0
    warn "Homebrew bootstrap failed. Continuing with critical dotfiles setup"
  fi

  if [ "$brew_ready" -eq 1 ]; then
    if ! apply_brewfile; then
      brew_bundle_ok=0
      warn "brew bundle failed. Continuing with symlinks and shell setup"
    fi
  fi

  validate_critical_binaries
  ensure_zsh_in_etc_shells
  ensure_default_shell_zsh

  if [ "$brew_ready" -eq 1 ]; then
    ensure_claude_code
  else
    warn "Skipping Claude Code install because Homebrew bootstrap did not complete"
  fi

  if [ "$brew_ready" -eq 0 ] || [ "$brew_bundle_ok" -eq 0 ]; then
    return 1
  fi
}

run_links_phase() {
  ensure_zsh_runtime_paths
  link_core_configs
  verify_shell_integrations
  ensure_ghostty_uses_zsh
}

run_opencode_phase() {
  opencode_base_phase
  opencode_sync_phase
}

run_phase() {
  local phase_name="$1"
  local severity="$2"
  shift 2

  log "---- Phase start: $phase_name ----"
  if "$@"; then
    log "---- Phase OK: $phase_name ----"
    return 0
  fi

  if [ "$severity" = "optional" ]; then
    PHASE_WARNINGS=$((PHASE_WARNINGS + 1))
    warn "Phase failed but is optional: $phase_name"
    return 0
  fi

  PHASE_ERRORS=$((PHASE_ERRORS + 1))
  err "Phase failed and is required: $phase_name"
  return 1
}

main() {
  trap 'on_error $LINENO $?' ERR
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
      run_phase "brew" "optional" run_brew_phase
      run_phase "links" "required" run_links_phase
      run_phase "opencode" "required" run_opencode_phase
      ;;
    brew)
      run_phase "brew" "required" run_brew_phase
      ;;
    links)
      run_phase "links" "required" run_links_phase
      ;;
    opencode)
      run_phase "opencode" "required" run_opencode_phase
      ;;
  esac

  if [ "$PHASE_ERRORS" -gt 0 ]; then
    err "Installer finished with required phase failures ($PHASE_ERRORS)"
    print_troubleshooting_hints
    exit 1
  fi

  if [ "$PHASE_WARNINGS" -gt 0 ]; then
    warn "Installer finished with warnings ($PHASE_WARNINGS); critical setup applied"
    print_troubleshooting_hints
  fi

  log "Done"
}

main "$@"
