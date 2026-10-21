#!/usr/bin/env bash
#
# build.sh — compila o Rodízio (as contas Claude na barra de menus) e o widget,
# gera o ícone, instala em ~/Applications, registra o widget e um LaunchAgent
# para abrir no login. Precisa do Xcode (SwiftUI/WidgetKit) e do claude-auto
# em ~/.local/bin. Assina com o certificado "Apple Development" se houver um
# (Xcode → Settings → Accounts); sem ele, assina ad-hoc.
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

WX="$APP/Contents/PlugIns/RodizioWidget.appex"
LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SIGN="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $2; exit }')"
SIGN="${SIGN:--}"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$WX/Contents/MacOS"
swiftc -O -parse-as-library "$DIR/Rodizio.swift" "$DIR/Shared.swift" "$DIR/WidgetViews.swift" \
  -o "$APP/Contents/MacOS/Rodizio"
swiftc -O -parse-as-library -application-extension "$DIR/Shared.swift" "$DIR/WidgetViews.swift" "$DIR/Widget.swift" \
  -o "$WX/Contents/MacOS/RodizioWidget"

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
  <key>CFBundleShortVersionString</key><string>2.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>$LABEL</string>
    <key>CFBundleURLSchemes</key><array><string>rodizio</string></array>
  </dict></array>
</dict>
</plist>
EOF

# Widget: extensão WidgetKit (sandbox obrigatório). Sem App Group, que exige
# certificado: lê o retrato que o app grava em ~/Library/Application Support/Rodizio,
# liberado por uma exceção só de leitura.
cat > "$WX/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$LABEL.widget</string>
  <key>CFBundleName</key><string>RodizioWidget</string>
  <key>CFBundleDisplayName</key><string>Rodízio</string>
  <key>CFBundleExecutable</key><string>RodizioWidget</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>2.1</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSExtension</key>
  <dict><key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string></dict>
</dict>
</plist>
EOF
cat > "$TMP/widget.entitlements" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
  <array><string>/Library/Application Support/Rodizio/</string></array>
</dict>
</plist>
EOF
# Primeiro a extensão (com os entitlements dela), depois o app por fora.
codesign --force --sign "$SIGN" --entitlements "$TMP/widget.entitlements" "$WX" >/dev/null 2>&1
codesign --force --sign "$SIGN" "$APP" >/dev/null 2>&1

# Registra o app e o widget no sistema (a galeria de widgets lê daqui).
pkill -f "RodizioWidget.appex" 2>/dev/null || true
"$LS" -f "$APP"
pluginkit -a "$WX"

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
