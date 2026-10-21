#!/usr/bin/env bash
#
# build.sh — compila o Rodízio (as contas Claude na barra de menus), gera o
# ícone, instala em ~/Applications e registra um LaunchAgent para abrir no login.
# Precisa do Xcode (SwiftUI) e do claude-auto em ~/.local/bin.
# Uso:  bash rodizio/build.sh
# Seguro rodar várias vezes: recompila e reinicia o app.
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HOME/Applications/Rodizio.app"
LABEL="com.rannimontagna.rodizio"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Versão anterior, quando o app se chamava ClaudeAutoBar.
OLD_LABEL="com.rannimontagna.claude-auto-bar"
launchctl bootout "gui/$(id -u)/$OLD_LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
rm -rf "$HOME/Applications/ClaudeAutoBar.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -parse-as-library "$DIR/Rodizio.swift" -o "$APP/Contents/MacOS/Rodizio"

# Ícone: o próprio app desenha o espeto em 1024 px; o resto sai dele.
"$APP/Contents/MacOS/Rodizio" --icon "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

# LSUIElement: só na barra de menus, sem ícone no Dock.
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleName</key><string>Rodízio</string>
  <key>CFBundleDisplayName</key><string>Rodízio</string>
  <key>CFBundleExecutable</key><string>Rodizio</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>2.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP" >/dev/null 2>&1

# Abre no login; se cair por erro, volta. "Sair" no painel encerra até o
# próximo login, e "Abrir junto com o Mac" nos Ajustes liga e desliga o job.
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$APP/Contents/MacOS/Rodizio</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Rodízio instalado em $APP e rodando (LaunchAgent $LABEL)."
