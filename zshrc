# ~/.zshrc — gerenciado pelo repo mac-setup (symlink)

# --- Segredos locais (NÃO versionados — ver ~/.secrets.zsh) ---
[ -f "$HOME/.secrets.zsh" ] && source "$HOME/.secrets.zsh"

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

# --- Android / mobile ---
# JDK 17 (para Gradle / React Native run-android)
[ -x /opt/homebrew/opt/openjdk@17/bin/java ] && export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
# Android SDK (instalado pelo Android Studio)
export ANDROID_HOME="$HOME/Library/Android/sdk"
if [ -d "$ANDROID_HOME" ]; then
  export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin"
fi

# --- Go ---
command -v go >/dev/null 2>&1 && export PATH="$PATH:$(go env GOPATH)/bin"

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
alias ios='open -a Simulator'                    # abre o iOS Simulator
alias ios-list='xcrun simctl list devices'       # lista os simuladores

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

# LM Studio CLI (lms)
[ -d "$HOME/.lmstudio/bin" ] && export PATH="$PATH:$HOME/.lmstudio/bin"

export PATH="$HOME/.local/bin:$PATH"

# gh multi-conta: lemon dentro de ~/Projetos/empresa/lemon (ou remote
# lemonenergy/); pessoal em todo o resto. Só shells interativos têm a
# função — a conta ativa do keyring fica na pessoal como default seguro
# para sessões não-interativas (scripts, IDEs, agentes).
gh() {
  # GITHUB_TOKEN é só pro npm (GitHub Packages); gh usa keyring
  if [[ "$PWD" == "$HOME/Projetos/empresa/lemon"* ]] \
    || command git remote get-url origin 2>/dev/null | grep -q "lemonenergy/"; then
    env -u GITHUB_TOKEN command gh auth switch -u raniellimontagna-lemon >/dev/null 2>&1
  else
    env -u GITHUB_TOKEN command gh auth switch -u raniellimontagna >/dev/null 2>&1
  fi
  env -u GITHUB_TOKEN command gh "$@"
}

# GitHub Packages (@lemonenergy) — token do registry privado só existe
# dentro da pasta lemon; fora dela a env var some para não vazar a conta
# lemon para ferramentas que honram GITHUB_TOKEN (gh, act, octokit...).
_lemon_github_token_hook() {
  if [[ "$PWD" == "$HOME/Projetos/empresa/lemon"* ]]; then
    if [ -z "${GITHUB_TOKEN:-}" ]; then
      export GITHUB_TOKEN=$(env -u GITHUB_TOKEN command gh auth token --user raniellimontagna-lemon 2>/dev/null)
    fi
  else
    unset GITHUB_TOKEN
  fi
}
autoload -U add-zsh-hook
add-zsh-hook chpwd _lemon_github_token_hook
_lemon_github_token_hook

# AWS SSO (Lemon) — preenche o account/role que o `lemon auth aws` (lemon-tech-cli) deixa como CONFIGURE_ME
export LEMON_AWS_ACCOUNT_ID="802790721360"
export LEMON_AWS_ROLE_NAME="AWSAdministratorAccess"
