#!/usr/bin/env bash
#
# mobile-ios.sh — prepara o Xcode e cria/inicia um iPhone no iOS Simulator.
# Roda com SUA senha (precisa de sudo para trocar o Xcode ativo e aceitar licença).
# Uso:  bash mobile-ios.sh
#
set -euo pipefail
info(){ printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"; }

XCODE="/Applications/Xcode.app"
if [ ! -d "$XCODE/Contents/Developer" ]; then
  echo "❌ Xcode completo não encontrado em $XCODE."
  echo "   Instale o Xcode pela App Store e rode de novo."
  exit 1
fi

info "1/5  Apontando o xcode-select para o Xcode (sudo)..."
sudo xcode-select -s "$XCODE/Contents/Developer"

info "2/5  Aceitando a licença do Xcode (sudo)..."
sudo xcodebuild -license accept

info "3/5  Primeiro launch / componentes (sudo)..."
sudo xcodebuild -runFirstLaunch

info "4/5  Baixando o runtime do iOS (alguns GB, pode demorar)..."
xcodebuild -downloadPlatform iOS

info "5/5  Criando e iniciando um iPhone..."
# Pega o iPhone e o runtime iOS MAIS NOVOS (ordenação por versão — não use tail,
# a lista não vem ordenada e pode cair num device velho e incompatível).
DEVTYPE="$(xcrun simctl list devicetypes 2>/dev/null \
  | grep -oE 'com.apple.CoreSimulator.SimDeviceType.iPhone-[0-9][0-9A-Za-z-]*' \
  | awk -F 'iPhone-' '{print $2"\t"$0}' | sort -rV | head -1 | cut -f2-)"
RUNTIME="$(xcrun simctl list runtimes 2>/dev/null \
  | grep -oE 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9][0-9-]*' | sort -rV | head -1)"
echo "  device: $DEVTYPE"
echo "  runtime: $RUNTIME"

# Cria só se ainda não existir um simulador com esse nome
NAME="iPhone (dev)"
if ! xcrun simctl list devices | grep -q "$NAME ("; then
  UDID="$(xcrun simctl create "$NAME" "$DEVTYPE" "$RUNTIME")"
  echo "  criado: $UDID"
fi

xcrun simctl boot "$NAME" 2>/dev/null || true
open -a Simulator

echo ""
echo "✅ iPhone iniciado no Simulator!"
echo "   Dica: liste com 'xcrun simctl list devices' | abra com 'open -a Simulator'."
