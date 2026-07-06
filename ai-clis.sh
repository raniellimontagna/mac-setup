#!/usr/bin/env bash
#
# ai-clis.sh — instala os CLIs de IA que uso, pelos canais oficiais.
# Rode manualmente:  bash ai-clis.sh
#
# Observação: eu uso o app **Superset** (https://superset.com) como "hub" que
# agrupa esses agentes num terminal só. O Superset apenas ENVOLVE os CLIs reais
# — ele não os instala. Então:
#   1) Instale o app Superset pelo site dele (não é o `superset` do Homebrew,
#      que é o Apache Superset de BI — coisa diferente).
#   2) Rode este script para ter os CLIs reais no PATH (funcionam soltos e
#      também são detectados pelos wrappers do Superset).
#
set -euo pipefail

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
command -v fnm >/dev/null 2>&1 && eval "$(fnm env)" 2>/dev/null || true

echo "==> Claude Code (Anthropic)"
npm install -g @anthropic-ai/claude-code

echo "==> Codex (OpenAI)"
npm install -g @openai/codex

echo "==> Gemini CLI (Google)"
npm install -g @google/gemini-cli

echo "==> opencode (SST)"
npm install -g opencode-ai

echo ""
echo "==> Rodando scripts de pós-instalação"
# O npm 11 bloqueia postinstall por padrão (allowlist "trusted identity"), então
# disparamos manualmente os scripts nativos/necessários dos pacotes globais.
GROOT="$(npm root -g)"
run_pi() { # <dir> <comando> <nome>
  if [ -d "$1" ]; then
    ( cd "$1" && eval "$2" ) >/dev/null 2>&1 && echo "  ✅ $3" || echo "  ⚠️ $3 (rode manualmente se der problema)"
  fi
}
run_pi "$GROOT/@anthropic-ai/claude-code" "AUTHORIZED=1 node install.cjs" "claude-code"
run_pi "$GROOT/opencode-ai" "node ./postinstall.mjs" "opencode"
run_pi "$GROOT/@google/gemini-cli/node_modules/@github/keytar" "node script/install.js || npm run build" "keytar (gemini)"
run_pi "$GROOT/@google/gemini-cli/node_modules/node-pty" "npx --yes node-gyp rebuild && { [ -f scripts/post-install.js ] && node scripts/post-install.js || true; }" "node-pty (gemini)"

echo ""
echo "Instalados. Versões:"
for c in claude codex gemini opencode; do
  command -v "$c" >/dev/null 2>&1 && printf "  %-9s %s\n" "$c" "$($c --version 2>/dev/null | head -1)" || printf "  %-9s (rode 'hash -r' ou reabra o terminal)\n" "$c"
done

echo ""
echo "Dica: como os globais do npm ficam atrelados à versão do Node (fnm),"
echo "rode este script de novo se trocar a versão default do Node."
