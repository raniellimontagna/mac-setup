#!/usr/bin/env bash
#
# maestri-team.sh
# Monta time no Maestri: Batuta (Codex) orquestra, ForjaN (Codex gpt-5.6-luna) executam
# (EXEC_COUNT define quantos), Sonar (Claude) revisa.
# Todos em modo full-permission (zero prompts).
#
# Uso:
#   ./maestri-team.sh [DIR_DO_PROJETO] ["TAREFA INICIAL"]
#
#   DIR_DO_PROJETO  diretório onde os agentes trabalham (default: diretório atual)
#   TAREFA INICIAL  se presente, já delega ao Batuta no final
#
# IMPORTANTE:
#   - Rode DENTRO de um terminal do Maestri COM O TOGGLE MAESTRO ATIVO.
#   - Os agentes rodam SEM NENHUMA CONFIRMAÇÃO: podem executar qualquer
#     comando, editar/apagar arquivos e acessar rede. Use em diretório
#     com git limpo/commitado.
#
set -uo pipefail

# ===== Config =====
ORCH_MODEL=""   # modelo do orquestrador (vazio = default do Codex). Ex: "gpt-5.2-codex"
EXEC_MODEL="gpt-5.6-luna"   # modelo dos executores Codex (mais barato que o default)
EXEC_EFFORT="medium"        # reasoning effort dos executores (low|medium|high)
EXEC_COUNT=2    # quantos executores recrutar

ORCH_NAME="Batuta"
EXEC_BASE="Forja"   # executores viram Forja1, Forja2, ...
REV_NAME="Sonar"

# ===== Args =====
WORKDIR="${1:-$PWD}"
KICKOFF="${2:-}"

WORKDIR="$(cd "$WORKDIR" 2>/dev/null && pwd)" || {
  echo "❌ Diretório não existe: ${1:-$PWD}" >&2
  exit 1
}

# ===== Guards =====
if [ -z "${MAESTRI_SOCKET:-}" ] || [ -z "${MAESTRI_TERMINAL_ID:-}" ]; then
  echo "❌ Rode dentro de um terminal do Maestri (MAESTRI_SOCKET ausente)." >&2
  exit 1
fi

MAESTRI="$(command -v maestri || echo /Applications/Maestri.app/Contents/Resources/maestri)"

fail() { echo "❌ $1" >&2; exit 1; }

# Testa Maestro ativo com comando real (role list é Maestro-only e inofensivo)
if ! "$MAESTRI" role list >/dev/null 2>&1; then
  fail "Este terminal não é o Maestro. Ative o toggle Maestro NESTE terminal no canvas e rode de novo."
fi

# ===== Comandos dos agentes (full permission) =====
ORCH_CMD="codex --yolo -C '$WORKDIR'"
[ -n "$ORCH_MODEL" ] && ORCH_CMD="$ORCH_CMD -m '$ORCH_MODEL'"

EXEC_CMD="codex --yolo -C '$WORKDIR'"
[ -n "$EXEC_MODEL" ] && EXEC_CMD="$EXEC_CMD -m '$EXEC_MODEL'"
[ -n "$EXEC_EFFORT" ] && EXEC_CMD="$EXEC_CMD -c model_reasoning_effort='$EXEC_EFFORT'"

# caminho absoluto: fnm troca de Node ao entrar no WORKDIR e o 'claude' some do PATH
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/share/fnm/node-versions/v24.18.0/installation/bin/claude")"
REV_CMD="cd '$WORKDIR' && '$CLAUDE_BIN' --dangerously-skip-permissions"

# Nomes dos executores: Forja1..ForjaN
EXEC_NAMES=()
for i in $(seq 1 "$EXEC_COUNT"); do EXEC_NAMES+=("$EXEC_BASE$i"); done
EXEC_LIST="${EXEC_NAMES[*]}"

# ===== Prompts dos roles =====
ORCH_PROMPT='Você é o ORQUESTRADOR ("'"$ORCH_NAME"'"). Você PLANEJA e COORDENA — nunca implementa. Executores: '"$EXEC_LIST"'. Revisor: "'"$REV_NAME"'".

Seus teammates são TERMINAIS EXTERNOS no canvas Maestri, não subagentes seus. Delegar = executar o comando shell "maestri ask" (o binário maestri está no PATH; fallback: $MAESTRI_CLI). PROIBIDO spawnar subagentes internos, colaboradores ou threads do seu próprio CLI para fazer o papel de executor/revisor — se você mesmo criar um "Forja" interno, os executores reais ficam ociosos e o fluxo quebra.

Rode o comando shell "maestri list" antes de tudo para confirmar seus teammates.

Loop de trabalho:
1. Decomponha o objetivo em tarefas pequenas, atômicas e verificáveis. Mantenha um plano curto e numerado no seu contexto; atualize a cada passo.
2. Delegue UMA tarefa por executor: maestri ask "<executor>" "<tarefa>". Toda delegação inclui: (a) tarefa exata, (b) contexto/arquivos, (c) "done when: <critério objetivo>".
3. Tarefas independentes: distribua entre os executores em paralelo com maestri ask --batch. NUNCA dê a dois executores tarefas que tocam os mesmos arquivos ao mesmo tempo — conflito de escrita.
4. Quando um executor entregar, mande para revisão: maestri ask "'"$REV_NAME"'" "Revise esta entrega contra o critério: <critério>. Entrega: <resumo + arquivos>".
5. Revisor apontou problema => devolva ao MESMO executor com a lista exata do que corrigir. Revisor aprovou => integre e siga.
6. NUNCA pare para pedir permissão ou opinião ao humano. Diante de ambiguidade ou trade-off, decida sozinho pelo caminho mais seguro e reversível (preservar trabalho existente, criar branch nova, nunca descartar mudanças, nunca force-push) e registre a decisão no seu plano. Fale com o humano apenas UMA vez: ao entregar o resultado final, com resumo do que foi feito e das decisões tomadas.

Regras: nunca escreva implementação; nunca aceite entrega sem revisão do "'"$REV_NAME"'"; delegações sempre específicas, nunca vagas; nunca bloqueie o fluxo esperando resposta do humano.

Economia de contexto: prefira SEMPRE o proxy rtk nos comandos de shell (rtk git status/log/diff, rtk grep, rtk rg, rtk read, rtk pnpm, rtk err, rtk test) — ele filtra e resume a saída antes de entrar no seu contexto. Comando nativo só quando o rtk não cobrir o caso.'

EXEC_PROMPT='Você é um EXECUTOR do time. Implementa exatamente o que o orquestrador "'"$ORCH_NAME"'" delegar. Não expanda escopo.

Como trabalhar:
1. Execute a tarefa por completo, atendendo o "done when" informado.
2. Ambíguo ou travado? PERGUNTE antes de chutar: maestri ask "'"$ORCH_NAME"'" "<dúvida objetiva>".
3. Report padrão ao terminar (sempre neste formato):
   - FEZ: o que implementou
   - ARQUIVOS: caminhos alterados/criados
   - VERIFICAR: comando ou passo para conferir
   - RISCOS: ressalvas, dívidas, o que não cobriu
4. Falhou algo? Diga claramente o que e por quê — nunca esconda erro.

Regra de ouro: fidelidade à tarefa acima de velocidade.

Economia de contexto: prefira SEMPRE o proxy rtk nos comandos de shell (rtk git, rtk grep, rtk rg, rtk read, rtk pnpm, rtk err, rtk test) — ele filtra e resume a saída antes de entrar no seu contexto. Comando nativo só quando o rtk não cobrir o caso. Reports sempre no formato padrão, sem prosa extra.'

REV_PROMPT='Você é o REVISOR ("'"$REV_NAME"'"). Revisa entregas do executor a pedido do orquestrador "'"$ORCH_NAME"'". Você NUNCA implementa nem edita arquivos — apenas lê e opina.

Como revisar:
1. Leia os arquivos citados e o diff real (git diff/log) — não confie só no resumo.
2. Cheque contra o critério "done when" informado. Critério não veio? Peça ao orquestrador.
3. Procure: bugs, casos de borda, quebra de código existente, desvio do pedido, risco de segurança.
4. Veredito padrão (sempre neste formato):
   - VEREDITO: APROVADO ou REPROVADO
   - PROBLEMAS: lista numerada com arquivo:linha (vazia se aprovado)
   - SUGESTÕES: melhorias opcionais, separadas dos problemas bloqueantes

Seja duro com problema real, não com estilo. Sem nitpick de formatação.

Economia de contexto: prefira SEMPRE o proxy rtk nos comandos de shell (rtk git diff/log, rtk grep, rtk rg, rtk read, rtk test) — ele filtra e resume a saída antes de entrar no seu contexto. Vereditos secos, sem prosa extra.'

# ===== Roles (idempotente: create -> write se já existe) =====
echo "==> Roles..."
upsert_role() {
  local name="$1" prompt="$2"
  if ! "$MAESTRI" role create "$name" "$prompt" 2>/dev/null; then
    "$MAESTRI" role write "$name" "$prompt" || fail "Não consegui criar/atualizar role '$name'."
    echo "  role '$name' atualizado."
  fi
}
upsert_role "Orquestrador" "$ORCH_PROMPT"
upsert_role "Executor" "$EXEC_PROMPT"
upsert_role "Revisor" "$REV_PROMPT"

# ===== Recrutar =====
echo "==> Recrutando (workdir: $WORKDIR)..."
"$MAESTRI" recruit "$ORCH_NAME" --command "$ORCH_CMD" --role "Orquestrador" || fail "Falha ao recrutar $ORCH_NAME (já existe no canvas?)."
for name in "${EXEC_NAMES[@]}"; do
  "$MAESTRI" recruit "$name" --command "$EXEC_CMD" --role "Executor" || fail "Falha ao recrutar $name (já existe no canvas?)."
done
"$MAESTRI" recruit "$REV_NAME"  --command "$REV_CMD"  --role "Revisor"    || fail "Falha ao recrutar $REV_NAME (já existe no canvas?)."

# ===== Conectar =====
echo "==> Conectando..."
for name in "${EXEC_NAMES[@]}"; do
  "$MAESTRI" connect "$ORCH_NAME" "$name" || fail "Falha ao conectar $ORCH_NAME <-> $name."
done
"$MAESTRI" connect "$ORCH_NAME" "$REV_NAME" || fail "Falha ao conectar $ORCH_NAME <-> $REV_NAME."

echo ""
echo "✅ Time pronto em $WORKDIR"
echo "   $ORCH_NAME (Codex, orquestra) <-> $EXEC_LIST (Codex $EXEC_MODEL, executam)"
echo "   $ORCH_NAME <-> $REV_NAME (Claude, revisa)"

# ===== Kickoff =====
if [ -n "$KICKOFF" ]; then
  echo ""
  echo "==> Delegando tarefa inicial ao $ORCH_NAME..."
  sleep 5  # dá tempo dos CLIs abrirem
  "$MAESTRI" ask "$ORCH_NAME" "$KICKOFF" || fail "Falha ao delegar. Delegue manualmente: maestri ask \"$ORCH_NAME\" \"...\""
else
  echo ""
  echo "Delegue com: maestri ask \"$ORCH_NAME\" \"<sua tarefa>\""
fi
