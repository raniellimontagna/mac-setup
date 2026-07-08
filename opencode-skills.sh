#!/usr/bin/env bash
#
# opencode-skills.sh — expõe skills de plugins do Claude Code para o opencode.
# Cria symlinks em ~/.config/opencode/skills (pasta que SÓ o opencode lê,
# então não interfere no Claude Code). Idempotente — rode de novo após
# atualizar os plugins (ele re-aponta pra versão mais nova).
#
# NÃO inclui o gsd: ele tem instalador multi-runtime próprio (@opengsd/gsd-core,
# veja gsd-install.sh) que já instala nativo no opencode, Claude Code e Codex.
#
set -uo pipefail

DEST="$HOME/.config/opencode/skills"
mkdir -p "$DEST"

link_skills() { # <glob-do-dir-skills> <rótulo>
  local dir
  dir=$(ls -d $1 2>/dev/null | sort -V | tail -1)
  if [ -z "${dir:-}" ] || [ ! -d "$dir" ]; then
    echo "  ⚠️  $2: skills não encontrados (o plugin está instalado?)"
    return
  fi
  local n=0 skill name
  for skill in "$dir"/*/; do
    skill="${skill%/}"
    [ -f "$skill/SKILL.md" ] || continue
    name="$(basename "$skill")"
    ln -sfn "$skill" "$DEST/$name"
    n=$((n + 1))
  done
  echo "  ✅ $2: $n skills → opencode"
}

echo "Expondo skills do Claude Code para o opencode em: $DEST"
link_skills "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills" "superpowers"
link_skills "$HOME/.claude/plugins/cache/caveman/caveman/*/skills" "caveman"

echo ""
echo "Skills visíveis pro opencode:"
/bin/ls -1 "$DEST" 2>/dev/null | sed 's/^/  /'
