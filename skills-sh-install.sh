#!/usr/bin/env bash
#
# skills-sh-install.sh — instala skills do registro skills.sh (npx skills@latest)
# que uso globalmente. Diferente de claude-plugins.sh: skills.sh distribui pastas
# skills/ soltas de repositórios GitHub, não plugins de marketplace. Rode de novo
# para atualizar (o instalador reescreve o destino).
#
set -uo pipefail
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
command -v fnm >/dev/null 2>&1 && eval "$(fnm env)" 2>/dev/null || true

install_skill() { # <repo-github> <skill> <label>
  echo "==> $3 ($2)"
  npx --yes skills@latest add "$1" -s "$2" -a claude-code -g -y 2>&1 | tail -6 || echo "  ⚠️  falha em $2"
  echo ""
}

# grill-me: entrevista o agente te faz sobre um plano/design antes de implementar
# (/grill-me). Depende do skill "grilling" (a lógica real fica lá).
install_skill mattpocock/skills grill-me "Matt Pocock — grill-me"
install_skill mattpocock/skills grilling "Matt Pocock — grilling (dependência do grill-me)"

# grill-with-docs: mesma entrevista, mas escreve CONTEXT.md (glossário) e ADRs
# no repo conforme as decisões fecham. Depende do skill "domain-modeling".
install_skill mattpocock/skills grill-with-docs "Matt Pocock — grill-with-docs"
install_skill mattpocock/skills domain-modeling "Matt Pocock — domain-modeling (dependência do grill-with-docs)"

echo "Skills instalados em ~/.claude/skills/. Reinicie o Claude Code."
echo "Uso: peça pra revisar um plano/design (ex.: 'quero que você me entreviste"
echo "sobre esse plano antes de implementar', ou invoque a skill grill-me)."
