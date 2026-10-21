#!/usr/bin/env bash
#
# build.sh — compila o ClaudeAutoBar (cotas das contas Claude na barra de menu),
# instala em ~/Applications e registra um LaunchAgent para abrir no login.
# Precisa do Xcode (SwiftUI) e do claude-auto em ~/.local/bin.
# Uso:  bash claude-auto-bar/build.sh
# Seguro rodar várias vezes: recompila e reinicia o app.
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HOME/Applications/ClaudeAutoBar.app"
LABEL="com.rannimontagna.claude-auto-bar"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$APP/Contents/MacOS"
swiftc -O -parse-as-library "$DIR/ClaudeAutoBar.swift" -o "$APP/Contents/MacOS/ClaudeAutoBar"

# LSUIElement: só na barra de menu, sem ícone no Dock.
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleName</key><string>ClaudeAutoBar</string>
  <key>CFBundleExecutable</key><string>ClaudeAutoBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP" >/dev/null 2>&1

# Abre no login; se cair por erro, volta. "Sair" no painel encerra de vez
# (saída limpa) até o próximo login.
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$APP/Contents/MacOS/ClaudeAutoBar</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "ClaudeAutoBar instalado em $APP e rodando (LaunchAgent $LABEL)."
