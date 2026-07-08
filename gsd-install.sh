#!/usr/bin/env bash
#
# gsd-install.sh — instala o GSD oficial (@opengsd/gsd-core) nos runtimes que uso:
# Claude Code, Codex e opencode (instalação global). Rode de novo para atualizar.
#
# GSD (Get Shit Done / opengsd.net) é multi-runtime — este é o instalador oficial.
# Não copie arquivos de agents/ ou commands/ na mão; sempre use o instalador.
#
set -uo pipefail
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
command -v fnm >/dev/null 2>&1 && eval "$(fnm env)" 2>/dev/null || true

for rt in claude codex opencode; do
  echo "==> GSD → $rt"
  npx --yes @opengsd/gsd-core@latest --"$rt" --global || echo "  ⚠️  falha em $rt"
  echo ""
done

echo "Pronto. Reinicie cada runtime."
echo "Comandos: /gsd-new-project (novo), /gsd-onboard (repo existente),"
echo "          /gsd:quick, /gsd:execute-phase, /gsd:debug, etc."
