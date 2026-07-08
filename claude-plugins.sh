#!/usr/bin/env bash
#
# claude-plugins.sh — instala os plugins de Claude Code que eu sempre uso.
# Requer o CLI `claude` (instalado pelo ai-clis.sh). Seguro rodar de novo.
#
set -uo pipefail
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
command -v fnm >/dev/null 2>&1 && eval "$(fnm env)" 2>/dev/null || true

if ! command -v claude >/dev/null 2>&1; then
  echo "❌ 'claude' não encontrado no PATH. Rode antes: bash ai-clis.sh"
  exit 1
fi

add_install() { # <marketplace-repo-github> <plugin@marketplace>
  echo "==> $2"
  claude plugin marketplace add "$1" 2>&1 | tail -1 || true
  claude plugin install "$2"      2>&1 | tail -1 || true
}

add_install anthropics/claude-plugins-official superpowers@claude-plugins-official
add_install JuliusBrussee/caveman              caveman@caveman

echo ""
echo "Plugins instalados:"
claude plugin list 2>&1 | grep -iE "superpowers|caveman" || true

echo ""
echo "Obs.:"
echo "  - GSD (multi-runtime): rode 'bash gsd-install.sh' (@opengsd/gsd-core)."
echo "  - caveman no Codex: 'npx skills add JuliusBrussee/caveman -a codex'."
