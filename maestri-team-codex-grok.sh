#!/usr/bin/env bash
#
# maestri-team-codex-grok.sh
# Monta um time no Maestri: Codex = orquestrador, Grok 4.5 = executor.
#
# IMPORTANTE: rode ISTO DENTRO DE UM TERMINAL DO MAESTRI (o CLI `maestri`
# precisa do canvas ao vivo — MAESTRI_SOCKET/MAESTRI_TERMINAL_ID). Num shell
# comum ele recusa. Se um terminal do Maestri estiver aberto, cole e rode aqui.
#
set -uo pipefail

if [ -z "${MAESTRI_SOCKET:-}" ] || [ -z "${MAESTRI_TERMINAL_ID:-}" ]; then
  echo "❌ Este script precisa rodar DENTRO de um terminal do Maestri." >&2
  echo "   (MAESTRI_SOCKET/MAESTRI_TERMINAL_ID não estão definidos aqui.)" >&2
  echo "   Abra um terminal no canvas do Maestri e rode de novo." >&2
  exit 1
fi

MAESTRI="$(command -v maestri || echo /Applications/Maestri.app/Contents/Resources/maestri)"

ORCH_PROMPT='Você é o ORQUESTRADOR do time. Seu trabalho é PLANEJAR e COORDENAR — você NÃO implementa código diretamente. Toda execução vai para o executor "Grok".

Rode "maestri list" antes de tudo para ver seus teammates.

Loop de trabalho:
1. Entenda o objetivo e decomponha em tarefas pequenas, atômicas e verificáveis.
2. Delegue UMA tarefa por vez ao Grok com: maestri ask "Grok" "<tarefa>". Sempre inclua: (a) a tarefa exata, (b) contexto/arquivos necessários, (c) critério objetivo de pronto ("done when...").
3. Se houver tarefas independentes, delegue em paralelo com: maestri ask --batch.
4. Quando o Grok responder, REVISE criticamente contra o critério. Se não atender, devolva com o que faltou — não aceite trabalho que você não verificou.
5. Integre, siga para a próxima tarefa e mantenha um plano/estado curto no seu contexto.
6. Traga o humano para decisões que só ele pode tomar (escopo, trade-offs, algo ambíguo).

Regras: nunca escreva a implementação você mesmo; nunca aceite entrega sem checar; delegue tarefas específicas, nunca vagas.'

EXEC_PROMPT='Você é o EXECUTOR do time. Você implementa exatamente o que o orquestrador "Batuta" delegar — com foco, qualidade e sem inventar escopo.

Rode "maestri list" para ver quem te coordena.

Como trabalhar:
1. Execute a tarefa delegada por completo. Não expanda o escopo nem faça mudanças não pedidas.
2. Se a tarefa estiver ambígua ou você travar, PERGUNTE ao orquestrador antes de chutar: maestri ask "Batuta" "<dúvida objetiva>".
3. Ao terminar, reporte de forma concreta: o que fez, arquivos alterados, como verificar, e qualquer ressalva/risco.
4. Se algo der errado, diga claramente o que falhou — não esconda erro.

Regra de ouro: qualidade e fidelidade à tarefa acima de velocidade. Melhor perguntar do que entregar errado.'

echo "==> Criando roles..."
"$MAESTRI" role create "Orquestrador" "$ORCH_PROMPT" || echo "  (role Orquestrador já existe? ajuste com 'maestri role write')"
"$MAESTRI" role create "Executor" "$EXEC_PROMPT" || echo "  (role Executor já existe? ajuste com 'maestri role write')"

echo "==> Recrutando..."
"$MAESTRI" recruit "Batuta" --preset "Codex" --role "Orquestrador"
"$MAESTRI" recruit "Grok" --command "grok" --role "Executor"

echo "==> Conectando orquestrador <-> executor..."
"$MAESTRI" connect "Batuta" "Grok"

echo ""
echo "✅ Time pronto. Delegue a primeira tarefa:"
echo "   maestri ask \"Batuta\" \"<sua tarefa>\""
echo ""
echo "Obs.: garanta que o preset 'Codex' aponta pro modelo mais capaz."
echo "      O 'grok' (Grok Build) já roda Grok 4.5 por padrão."
