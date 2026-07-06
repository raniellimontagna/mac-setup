#!/usr/bin/env bash
#
# setup.sh — configura um Mac novo para desenvolvimento (Apple Silicon)
# Uso:  bash setup.sh
# Seguro rodar várias vezes (idempotente).
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info(){ printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p >/dev/null 2>&1; then
  info "Instalando Xcode Command Line Tools..."
  xcode-select --install
  echo "Conclua a instalação na janela que abriu e rode este script de novo."
  exit 0
fi

# --- 2. Homebrew ---
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
  info "Instalando Homebrew (vai pedir sua senha do Mac)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# --- 3. Pacotes (Brewfile) ---
info "Instalando pacotes do Brewfile..."
brew bundle --file="$DIR/Brewfile"

# --- 4. Git: identidade + defaults ---
info "Configurando Git..."
if [ -z "$(git config --global user.name || true)" ]; then
  read -rp "  Nome para os commits: " GIT_NAME
  read -rp "  Email para os commits: " GIT_EMAIL
  git config --global user.name  "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global push.autoSetupRemote true
git config --global fetch.prune true
git config --global core.editor "code --wait"
git config --global color.ui auto
git config --global rerere.enabled true
git config --global core.excludesfile "$HOME/.gitignore_global"

# Aliases úteis do git
git config --global alias.st "status -sb"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.cm "commit -m"
git config --global alias.lg "log --oneline --graph --decorate -20"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "reset HEAD --"

# --- 5. Chave SSH para o GitHub ---
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  info "Gerando chave SSH (ed25519)..."
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f ~/.ssh/id_ed25519 -N "" -q
  cat > ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
  UseKeychain yes
EOF
  chmod 600 ~/.ssh/config ~/.ssh/id_ed25519
  chmod 644 ~/.ssh/id_ed25519.pub
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || true
  echo ""
  echo "  >>> Adicione esta chave em https://github.com/settings/ssh/new :"
  echo ""
  cat ~/.ssh/id_ed25519.pub
  echo ""
fi

# --- 6. .zshrc + starship (symlinks para o repo) ---
info "Instalando .zshrc e config do Starship..."
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  echo "  Backup do .zshrc antigo em ~/.zshrc.backup"
fi
ln -sf "$DIR/zshrc" "$HOME/.zshrc"
ln -sf "$DIR/gitignore_global" "$HOME/.gitignore_global"
mkdir -p "$HOME/.config" "$HOME/.config/ghostty"
ln -sf "$DIR/starship.toml" "$HOME/.config/starship.toml"
ln -sf "$DIR/ghostty-config" "$HOME/.config/ghostty/config"

# --- 7. Node LTS via fnm + pnpm ---
info "Instalando Node LTS via fnm..."
eval "$(fnm env)"
fnm install --lts
fnm default lts-latest
eval "$(fnm env --use-on-cd)"
corepack enable
corepack prepare pnpm@latest --activate

# --- 8. Extensões do VS Code ---
if command -v code >/dev/null 2>&1 && [ -f "$DIR/vscode/extensions.txt" ]; then
  info "Instalando extensões do VS Code..."
  while IFS= read -r ext; do
    [ -n "$ext" ] && code --install-extension "$ext" --force >/dev/null 2>&1 && echo "  + $ext"
  done < "$DIR/vscode/extensions.txt"
fi

# --- 9. Estrutura de pastas ---
mkdir -p ~/Projetos/pessoal ~/Projetos/empresa

info "Concluído! Feche e reabra o terminal."
echo "Depois teste com:  ssh -T git@github.com"
