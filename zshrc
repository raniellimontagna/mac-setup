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

# gh multi-conta: dentro da pasta (ou da org) de trabalho usa a conta de
# trabalho; pessoal em todo o resto. Só shells interativos têm a função — a
# conta ativa do keyring fica na pessoal como default seguro para sessões
# não-interativas (scripts, IDEs, agentes).
#
# Este repo é PÚBLICO: nome de empresa, org e usuário de trabalho ficam em
# ~/.secrets.zsh (carregado lá em cima). Defina lá o que se aplicar:
#
#   WORK_PROJECT_DIR="$HOME/Projetos/empresa/<empresa>"
#   WORK_GH_ORG="<org-do-github>"
#   WORK_GH_USER="<usuario-github-de-trabalho>"
#   PERSONAL_GH_USER="<usuario-github-pessoal>"
#
# Sem essas variáveis nada quebra: tudo cai na conta pessoal.

# Só caminho — barato, roda a cada chpwd.
_is_work_dir() {
  [ -n "${WORK_PROJECT_DIR:-}" ] && [[ "$PWD" == "$WORK_PROJECT_DIR"* ]]
}
# Caminho OU remote — o `git remote` só vale a pena na chamada do gh.
_is_work_repo() {
  _is_work_dir && return 0
  [ -n "${WORK_GH_ORG:-}" ] \
    && command git remote get-url origin 2>/dev/null | grep -q "${WORK_GH_ORG}/"
}

gh() {
  # GITHUB_TOKEN é só pro npm (GitHub Packages); gh usa keyring
  local _acct="${PERSONAL_GH_USER:-}"
  if [ -n "${WORK_GH_USER:-}" ] && _is_work_repo; then
    _acct="$WORK_GH_USER"
  fi
  [ -n "$_acct" ] && env -u GITHUB_TOKEN command gh auth switch -u "$_acct" >/dev/null 2>&1
  env -u GITHUB_TOKEN command gh "$@"
}

# GitHub Packages de registry privado — o token só existe dentro da pasta de
# trabalho; fora dela a env var some para não vazar a conta de trabalho para
# ferramentas que honram GITHUB_TOKEN (gh, act, octokit...).
_work_github_token_hook() {
  if [ -n "${WORK_GH_USER:-}" ] && _is_work_dir; then
    if [ -z "${GITHUB_TOKEN:-}" ]; then
      export GITHUB_TOKEN=$(env -u GITHUB_TOKEN command gh auth token --user "$WORK_GH_USER" 2>/dev/null)
    fi
  else
    unset GITHUB_TOKEN
  fi
}
autoload -U add-zsh-hook
add-zsh-hook chpwd _work_github_token_hook
_work_github_token_hook

# AWS SSO do trabalho: os nomes das variáveis são específicos do CLI interno do
# empregador e os valores identificam a conta — os dois ficam em ~/.secrets.zsh.

# Claude Code multi-conta: cada perfil aponta para um CLAUDE_CONFIG_DIR
# próprio, então config, login, MCPs, skills/plugins e histórico ficam
# isolados. Para criar um perfil novo basta uma linha `claude_profile <nome>`
# — vira o comando `claude-<nome>` usando ~/.claude-<nome>. O segundo
# argumento (opcional) força outro diretório.
claude_profile() {
  local nome="$1" dir="${2:-$HOME/.claude-$1}"
  alias "claude-$nome"="CLAUDE_CONFIG_DIR='$dir' claude"
}
# `claude` puro = perfil pessoal. Sem este export ele usaria ~/.claude.json
# (config antiga, na raiz do home) e cairia numa terceira configuração,
# separada dos dois perfis. Os aliases sobrescrevem a variável na chamada.
export CLAUDE_CONFIG_DIR="$HOME/.claude"
claude_profile pessoal "$HOME/.claude"   # explícito; equivale ao `claude` puro
# Perfil de trabalho: o nome vem de ~/.secrets.zsh (WORK_PROFILE_NAME), porque
# identifica o empregador e este repo é público. Vira `claude-<nome>`.
[ -n "${WORK_PROFILE_NAME:-}" ] && claude_profile "$WORK_PROFILE_NAME"
# Contas extras do pessoal para rotacionar quando bate limite. Cada uma tem
# login próprio (.claude.json/.credentials.json no seu dir), mas config,
# skills, plugins, hooks e projects/ são symlinks para ~/.claude — então
# `claude-<nome> --continue` retoma a mesma sessão que estava no pessoal.
claude_profile_shared() {
  local nome="$1" dir="$HOME/.claude-$1" item
  mkdir -p "$dir"
  for item in CLAUDE.md RTK.md settings.json agents skills plugins hooks scripts projects; do
    [ -e "$HOME/.claude/$item" ] && [ ! -e "$dir/$item" ] && ln -s "$HOME/.claude/$item" "$dir/$item"
  done
  # MCPs de usuário moram no .claude.json (junto do login): copia só na criação.
  [ ! -e "$dir/.claude.json" ] && command -v jq >/dev/null &&
    jq '{mcpServers}' "$HOME/.claude/.claude.json" > "$dir/.claude.json" 2>/dev/null &&
    chmod 600 "$dir/.claude.json"
  claude_profile "$nome"
}
claude_profile_shared contato
claude_profile_shared ranielli
# `claude-seek` = Claude Code falando com a API compatível Anthropic do DeepSeek.
# Perfil isolado em ~/.claude-seek e variáveis só no escopo da chamada, então o
# `claude` normal não é afetado. A chave mora no Keychain (serviço deepseek-api-key)
# e só é lida quando o comando roda.
claude-seek() {
  local key
  key=$(security find-generic-password -s deepseek-api-key -w 2>/dev/null) || {
    echo "claude-seek: chave ausente no Keychain (serviço deepseek-api-key)" >&2
    return 1
  }
  CLAUDE_CONFIG_DIR="$HOME/.claude-seek" \
  ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic" \
  ANTHROPIC_AUTH_TOKEN="$key" \
  ANTHROPIC_MODEL="deepseek-flash[1m]" \
  ANTHROPIC_DEFAULT_FABLE_MODEL="deepseek-v4-pro[1m]" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-flash[1m]" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-flash[1m]" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-flash" \
  CLAUDE_CODE_SUBAGENT_MODEL="deepseek-flash" \
  CLAUDE_CODE_EFFORT_LEVEL="max" \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW="786432" \
  claude "$@"
}

# Codex CLI multi-conta: mesmo padrão do claude_profile, só que via CODEX_HOME
# (config.toml, auth.json, sessions e histórico ficam dentro do diretório).
# `codex_profile <nome>` vira o comando `codex-<nome>` usando ~/.codex-<nome>.
codex_profile() {
  local nome="$1" dir="${2:-$HOME/.codex-$1}"
  alias "codex-$nome"="CODEX_HOME='$dir' codex"
}
export CODEX_HOME="$HOME/.codex"
codex_profile pessoal "$HOME/.codex"     # explícito; equivale ao `codex` puro
codex_profile gui                        # conta do Gui, isolada em ~/.codex-gui
