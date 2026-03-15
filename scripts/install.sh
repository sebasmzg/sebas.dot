#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE_PATH="$REPO_ROOT/Brewfile"

log() {
  printf '[sebas.dot] %s\n' "$1"
}

backup_path() {
  local target="$1"
  local stamp
  stamp="$(date +%Y%m%d_%H%M%S)"
  mv "$target" "${target}.pre-sebasdot-backup-${stamp}"
}

safe_symlink() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    local current
    current="$(readlink "$target")"
    if [ "$current" = "$source" ]; then
      log "Symlink already OK: $target"
      return
    fi
    rm "$target"
  elif [ -e "$target" ]; then
    log "Backing up existing target: $target"
    backup_path "$target"
  fi

  ln -s "$source" "$target"
  log "Linked $target -> $source"
}

ensure_linuxbrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already available"
    return
  fi

  log "Installing Linuxbrew (generic bootstrap)"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || {
    log "ERROR: brew not available after installation"
    exit 1
  }
}

apply_brewfile() {
  log "Applying exact Brewfile"
  brew bundle --file "$BREWFILE_PATH"
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
  mkdir -p "$HOME/.config/opencode"
  if command -v opencode >/dev/null 2>&1; then
    log "Opencode CLI detected"
  else
    log "Opencode CLI not found in PATH (continuing with config sync)"
  fi
}

opencode_sync_phase() {
  log "Opencode phase 2/2: syncing config and skills"
  rsync -a --delete \
    --exclude 'node_modules/' \
    --exclude '*.bak' \
    --exclude '.env' \
    --exclude '.env.*' \
    --exclude 'secrets/' \
    "$REPO_ROOT/.config/opencode/" "$HOME/.config/opencode/"
}

main() {
  ensure_linuxbrew
  apply_brewfile
  link_core_configs
  opencode_base_phase
  opencode_sync_phase
  log "Done"
}

main "$@"
