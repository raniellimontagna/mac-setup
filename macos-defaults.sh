#!/usr/bin/env bash
#
# macos-defaults.sh — ajustes de sistema opcionais (rode manualmente).
# NÃO é chamado pelo setup.sh: rode só se concordar com as mudanças.
# Uso:  bash macos-defaults.sh
#
set -euo pipefail
echo "Aplicando ajustes do macOS..."

# --- Scroll estilo Linux/Windows (desliga rolagem natural) ---
# Comente esta linha se preferir manter a rolagem natural da Apple.
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# --- Teclado: repetição de tecla mais rápida (ótimo pra código) ---
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Permite segurar a tecla pra repetir (em vez do menu de acentos)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# --- Finder ---
defaults write com.apple.finder AppleShowAllFiles -bool true        # mostra arquivos ocultos
defaults write com.apple.finder ShowPathbar -bool true              # barra de caminho
defaults write com.apple.finder ShowStatusBar -bool true            # barra de status
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" # visão em lista
defaults write NSGlobalDomain AppleShowAllExtensions -bool true     # sempre mostra extensões
# Salva por padrão no disco, não no iCloud
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
# Evita criar .DS_Store em drives de rede/USB
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# --- Dock ---
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false

# --- Screenshots numa pasta dedicada ---
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"

echo "Reiniciando Finder e Dock para aplicar..."
killall Finder Dock 2>/dev/null || true
echo "Pronto! Alguns ajustes (teclado/scroll) só valem após sair e entrar na conta."
