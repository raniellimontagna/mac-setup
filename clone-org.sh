#!/usr/bin/env bash
#
# clone-org.sh — clona (ou atualiza) todos os repos de uma org do GitHub.
# Requer o gh CLI logado (gh auth login).
#
# Uso:
#   bash clone-org.sh <org> [pasta-destino]
#
# Exemplos:
#   bash clone-org.sh attodevlabs                      # -> ~/Projetos/empresa/attodevlabs
#   bash clone-org.sh attodevlabs ~/Projetos/empresa/atto
#
set -euo pipefail

ORG="${1:?uso: clone-org.sh <org> [pasta-destino]}"
DEST="${2:-$HOME/Projetos/empresa/$ORG}"

eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

mkdir -p "$DEST"
cd "$DEST"
echo "Clonando repos de '$ORG' em: $DEST"
echo ""

gh repo list "$ORG" --limit 500 --json nameWithOwner -q '.[].nameWithOwner' | while read -r repo; do
  name="${repo#*/}"
  if [ -d "$name/.git" ]; then
    printf "↻ %-40s atualizando... " "$name"
    git -C "$name" pull --ff-only -q 2>/dev/null && echo "ok" || echo "(pulei — tem mudanças locais)"
  else
    printf "⬇️  %-40s clonando... " "$name"
    gh repo clone "$repo" "$name" -- -q && echo "ok" || echo "FALHOU"
  fi
done

echo ""
echo "Concluído. Repos em: $DEST"
