# ~/.zshrc — gerenciado pelo repo mac-setup (symlink)

# --- Homebrew (Apple Silicon) ---
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- fnm (Fast Node Manager) ---
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

# --- pnpm / corepack ---
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# --- Editor padrão ---
export EDITOR="code --wait"

# --- Histórico melhor ---
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# --- CLI modernas ---
# eza (ls moderno). Se não existir, cai no ls normal.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --git --group-directories-first'
  alias lt='eza --tree --level=2 --icons'
else
  alias ll='ls -lah'
fi
# bat (cat com syntax highlight)
command -v bat >/dev/null 2>&1 && export BAT_THEME="ansi"
# zoxide (cd inteligente: use `z <parte-do-nome>`)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
# fzf (Ctrl+R histórico, Ctrl+T arquivos)
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh) 2>/dev/null

# --- Aliases úteis ---
alias lg='lazygit'
alias gs='git status'
alias gc='git commit'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias projetos='cd ~/Projetos'

# --- Autocompletion do git/brew ---
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi
autoload -Uz compinit && compinit

# --- Prompt: Starship ---
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# --- Plugins do zsh ---
# autosuggestions: sugere comandos do histórico (aceita com ->)
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# syntax-highlighting: colore o comando enquanto você digita.
# IMPORTANTE: precisa ser o ÚLTIMO source do arquivo.
[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
