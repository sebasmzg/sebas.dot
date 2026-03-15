# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Zsh Configuration
# OpenCode Dots - Powered by Powerlevel10k

# Path
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Powerlevel10k
source ~/.local/share/zsh/powerlevel10k/powerlevel10k.zsh-theme

# Autocompletado
autoload -Uz compinit
compinit -d ~/.local/share/zsh/zcompdump

# Historial mejorado
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.local/share/zsh/history

# Opciones de Zsh
setopt AUTO_CD
setopt GLOB_DOTS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# Integración con herramientas
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
fi

if command -v atuin &> /dev/null; then
    eval "$(atuin init zsh)"
fi

if command -v fzf &> /dev/null; then
    # Verificar rutas comunes de fzf en Ubuntu/Debian
    if [ -f /usr/share/doc/fzf/examples/completion.zsh ]; then
        source /usr/share/doc/fzf/examples/completion.zsh
        source /usr/share/doc/fzf/examples/key-bindings.zsh
    elif [ -f ~/.local/share/fzf/shell/completion.zsh ]; then
        source ~/.local/share/fzf/shell/completion.zsh
        source ~/.local/share/fzf/shell/key-bindings.zsh
    fi
fi

# Alias útiles
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Alias para Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'

# Alias para herramientas
alias vi='nvim'
alias vim='nvim'
alias zj='zellij'

# Funciones personalizadas
mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' no se puede extraer" ;;
        esac
    else
        echo "'$1' no es un archivo válido"
    fi
}

# Cargar configuración local si existe
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# OpenCode PATH
export PATH="$HOME/.opencode/bin:$PATH"

# Atuin PATH
export PATH="$HOME/.atuin/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
