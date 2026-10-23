# mac-setup

Script de configuração de um **Mac novo** para desenvolvimento (Apple Silicon).
Instala as ferramentas, configura Git e SSH, e prepara o ambiente Node — tudo com um comando.

## O que ele faz

- Instala o **Xcode Command Line Tools** (se faltar)
- Instala o **Homebrew**
- Instala pacotes e apps via [`Brewfile`](./Brewfile): `git`, `gh`, `fnm`, Starship, plugins do zsh, Nerd Font, **CLI modernas** (fzf, zoxide, eza, bat, fd, ripgrep, lazygit, git-delta, btop), OrbStack, VS Code, Ghostty, Chrome, Bruno, Mos
- Configura o **Git** (nome, email e defaults sensatos)
- Gera uma **chave SSH** (`ed25519`) e o `~/.ssh/config` usando o keychain do macOS
- Instala o [`.zshrc`](./zshrc), o [`starship.toml`](./starship.toml) e a [config do Ghostty](./ghostty-config) como symlinks
  - **Starship** no prompt (branch git, versão do Node, cores) + autosuggestions e syntax-highlighting
  - **Perfis do Claude Code** (`claude-pessoal` + um por conta de trabalho) — múltiplas contas com
    ambientes isolados, `claude-auto` para trocar de conta sozinho quando uma bate o limite e o
    Brasa para acompanhar o Mac e as cotas na barra de menus —
    veja [Múltiplas contas do Claude Code](#múltiplas-contas-do-claude-code)
- Configura **gitignore global** ([`gitignore_global`](./gitignore_global)) e **aliases** do git (`st`, `co`, `lg`, `cm`...)
- Instala o **Node LTS** via `fnm` e habilita **pnpm** via corepack
- Instala as **extensões do VS Code** de [`vscode/extensions.txt`](./vscode/extensions.txt)
- Cria a estrutura `~/Projetos/pessoal` e `~/Projetos/empresa`

### Extras (rode manualmente)

- **[`macos-defaults.sh`](./macos-defaults.sh)** — ajustes de sistema opcionais: scroll estilo Linux,
  repetição de tecla mais rápida, mostrar arquivos ocultos no Finder, Dock com autohide, etc.
  Revise antes e rode com `bash macos-defaults.sh`.
- **[`editorconfig`](./editorconfig)** — base de `.editorconfig`; copie para a raiz dos seus projetos.
- **[`clone-org.sh`](./clone-org.sh)** — clona (ou atualiza) todos os repos de uma org do GitHub.
  Ex.: `bash clone-org.sh minha-org ~/Projetos/empresa/minha-org`. Rodar de novo dá `git pull` nos existentes.
  Estrutura sugerida: `~/Projetos/empresa/<empresa>/<repo>` e `~/Projetos/pessoal/<repo>`.
- **[`mobile-ios.sh`](./mobile-ios.sh)** — aponta o `xcode-select` para o Xcode, baixa o runtime do
  iOS e cria/inicia um iPhone no Simulator. Precisa de `sudo` (senha) — rode com `bash mobile-ios.sh`.
  O SDK/emulador **Android** vem pelo Android Studio (abra-o uma vez e instale o SDK pelo assistente).
- **[`claude-plugins.sh`](./claude-plugins.sh)** — instala os plugins de Claude Code **superpowers** e
  **caveman**. Idempotente. Requer o `ai-clis.sh` antes (precisa do CLI `claude`).
  No Codex, o caveman é à parte: `npx skills add JuliusBrussee/caveman -a codex`.
- **[`gsd-install.sh`](./gsd-install.sh)** — instala o **GSD** oficial ([`@opengsd/gsd-core`](https://opengsd.net))
  nos **3 runtimes**: Claude Code, Codex e opencode (`--claude/--codex/--opencode --global`). É o instalador
  multi-runtime; comandos `/gsd:*`, `/gsd-new-project`, `/gsd-onboard`.
- **[`opencode-skills.sh`](./opencode-skills.sh)** — expõe os skills do **superpowers** e **caveman** para o
  **opencode** (symlinks em `~/.config/opencode/skills`, isolado do Claude Code). Idempotente — rode de novo
  após atualizar os plugins. (O **gsd** tem instalador multi-runtime próprio — veja `gsd-install.sh`.)
- **[`skills-sh-install.sh`](./skills-sh-install.sh)** — instala skills soltos do registro
  [skills.sh](https://skills.sh) (via `npx skills add`, diferente do marketplace de plugins do
  `claude-plugins.sh`). Hoje instala, de [mattpocock/skills](https://github.com/mattpocock/skills):
  **grill-me**/**grilling** (entrevista sobre um plano/design antes de implementar) e
  **grill-with-docs**/**domain-modeling** (mesma entrevista, mas registra glossário em `CONTEXT.md`
  e ADRs em `docs/adr/` no repo conforme as decisões fecham). Idempotente.
- **[`ai-clis.sh`](./ai-clis.sh)** — instala os CLIs de IA (Claude Code, Codex, Gemini, opencode)
  pelos canais oficiais. O app **Orca** (IDE/hub que agrupa esses agentes) é instalado à parte
  pelo site — ver abaixo.

### Apps instalados manualmente (sem cask)

- **Maestri** — canvas multi-agente; instalado pelo site. Time Codex+Grok: `maestri-team-codex-grok.sh`.
- **Orca** — IDE/hub principal que agrupa os agentes de IA (substituiu o Superset), com acesso
  remoto pelo celular. Instalado pelo site (o cask `orca` do Homebrew é o do Plotly, deprecated
  — não é este). Acesso mobile: o app
  escuta em `0.0.0.0:6768` (websocket com auth token); com **Tailscale** no Mac e no celular
  (mesma conta), aponte o app mobile para `<ip-tailscale-do-mac>:6768` ou
  `<hostname>:6768` via MagicDNS e pareie o dispositivo no Orca do Mac.

## Como usar num Mac novo

```bash
git clone git@github.com:raniellimontagna/mac-setup.git ~/Projetos/pessoal/mac-setup
cd ~/Projetos/pessoal/mac-setup
bash setup.sh
```

> Na primeira vez, se ainda não tiver chave SSH, clone via HTTPS:
> `git clone https://github.com/raniellimontagna/mac-setup.git`

O script é **idempotente**: pode rodar de novo sem quebrar nada.

## Depois de rodar

1. Adicione a chave SSH mostrada no fim em https://github.com/settings/ssh/new
2. Feche e reabra o terminal
3. Teste: `ssh -T git@github.com`
4. Login no GitHub CLI: `gh auth login`

## Repos privados de empresa

Clonar todos os repos de uma org: `bash clone-org.sh <org> ~/Projetos/empresa/<nome>`.
Para as dependências instalarem, alguns acessos precisam ser configurados (uma vez por Mac):

- **Módulos Go privados** — o `setup.sh` já configura `git ... insteadOf` (usa SSH). Marque os orgs:
  ```bash
  go env -w GOPRIVATE="github.com/<sua-org-1>,github.com/<sua-org-2>"
  ```
- **GitHub Packages privado** (`@<sua-org>/*` via pnpm) — precisa de token com escopo `read:packages`:
  ```bash
  gh auth refresh -h github.com -s read:packages
  printf '//npm.pkg.github.com/:_authToken=%s\n' "$(gh auth token)" >> ~/.npmrc && chmod 600 ~/.npmrc
  ```
  (o token fica só no `~/.npmrc` local — **nunca** comitar)
- **pnpm em repos com Node pinado** — use `corepack pnpm install` (funciona em qualquer versão do Node).

## Economia de tokens (agentes de IA)

Duas alavancas que reduzem consumo de token em sessões com agentes (Claude Code, Codex...):

- **rtk** (Rust Token Killer — já no `Brewfile`) — comprime a **saída de comandos** que o agente lê.
  Prefixe: `rtk git status`, `rtk pnpm install`, `rtk tsc`. Veja economia com `rtk gain`.
- **caveman** — plugin/skill que faz o **próprio agente responder comprimido** (~65% menos tokens de
  saída). **Não é brew** — instala dentro de cada agente:
  - **Claude Code:** `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman` (auto-ativa)
  - **Codex:** `npx skills add JuliusBrussee/caveman -a codex` (ative com `/caveman` uma vez por sessão)
  - Níveis: `/caveman lite` (tira só formalidades) → default → `full` → `ultra`. Comece no `lite`.

## Múltiplas contas do Claude Code

Dá para rodar mais de uma conta na mesma máquina com **ambientes isolados**: cada perfil tem seu
próprio `CLAUDE_CONFIG_DIR`, ou seja, config, login, servidores MCP, skills/plugins e histórico de
sessões separados. O [`zshrc`](./zshrc) já traz dois perfis prontos:

| Comando          | `CLAUDE_CONFIG_DIR` | Uso                                              |
| ---------------- | ------------------- | ------------------------------------------------ |
| `claude`         | `~/.claude`         | padrão (é a mesma config do `claude-pessoal`)    |
| `claude-pessoal` | `~/.claude`         | conta pessoal — apelido explícito do padrão      |
| `claude-<trab>`  | `~/.claude-<trab>`  | conta de trabalho, ambiente totalmente separado  |

O perfil de trabalho só existe se `WORK_PROFILE_NAME` estiver definido em `~/.secrets.zsh` —
o nome identifica o empregador e este repo é público. Para criar outros, uma linha basta:
`claude_profile <nome>`.

```bash
cd ~/Projetos/pessoal/algum-repo && claude-pessoal
cd ~/Projetos/empresa/<empresa>/algum-repo && claude-<trab>
```

### Adicionando um perfil novo

Uma linha no [`zshrc`](./zshrc), na seção de multi-conta:

```sh
claude_profile atto   # cria o comando `claude-atto` usando ~/.claude-atto
```

O segundo argumento é opcional e força outro diretório (é assim que o `pessoal` reaproveita a
config padrão):

```sh
claude_profile pessoal "$HOME/.claude"
```

Abra um terminal novo (ou `source ~/.zshrc`) e rode `claude-atto`.

> **Na primeira vez de cada perfil isolado** o diretório nasce vazio: faça o login
> (`claude-atto` → `/login`) e reinstale nele o que precisar — plugins, MCPs e skills **não** são
> compartilhados entre perfis, é justamente o ponto do isolamento. Os scripts deste repo aceitam
> o mesmo env var, então dá para reaproveitá-los por perfil:
>
> ```bash
> CLAUDE_CONFIG_DIR=~/.claude-<trab> bash claude-plugins.sh
> ```

### Contas extras para rotacionar (`claude_profile_shared`)

Quando as assinaturas são da mesma pessoa, o perfil extra não precisa ser isolado:
`claude_profile_shared <nome>` cria `~/.claude-<nome>` com login próprio, mas com `settings.json`,
skills, plugins, hooks e `projects/` como symlinks para o `~/.claude`. Como as sessões moram em
`projects/`, qualquer conta retoma a mesma conversa (`claude-<nome> --continue`).

### Troca automática de conta (`claude-auto`)

O [`claude-auto`](./claude-auto) roda o Claude Code passando de conta em conta quando uma bate o
limite, sem perder a sessão:

- **No limite**: quando a resposta falha com `rate_limit`, o hook `StopFailure` marca a conta como
  cheia até o reset e fecha o claude; o `claude-auto` reabre a mesma sessão (`--resume`) na próxima
  conta da fila, com uma mensagem pedindo para continuar de onde parou.
- **Antes do limite**: a statusline grava o uso (janelas de 5h e 7d) de cada conta; no fim de cada
  turno (hook `Stop`), se a conta passou de 95% e existe outra com folga, a troca acontece antes de
  uma resposta falhar no meio. Se a sessão só esperava você, ela volta quieta; se esperava um
  comando em segundo plano (servidor, build, monitor), que morre na troca, ela volta com uma
  mensagem para reiniciar o que faltar e continuar.
- **Sem aviso de confiança na retomada**: cada conta guarda no próprio `.claude.json` as pastas em
  que você confiou, então a sessão reaberta numa conta que nunca usou aquela pasta parava no aviso
  "Is this a project you created or one you trust?". Como o Claude Code só roda hook em pasta
  confiada, a troca prova que você já confiou nela: o `claude-auto` copia essa confiança para a
  conta nova. Na pasta pessoal (`~`) o Claude Code nunca grava a confiança e pergunta a cada
  abertura; ali a retomada usa o mesmo recurso com que o próprio Claude Code se reinicia sem
  perguntar (`CLAUDE_CODE_RELAUNCH_HOME_TRUST`, conferido contra o processo novo). A primeira
  abertura continua perguntando normalmente.
- **Zera antes, usa antes**: entre as contas com folga, a próxima é a que zera primeiro. O que sobra
  numa janela se perde quando ela zera, enquanto as outras guardam o saldo. Conta sem janela aberta
  não perde nada e vem depois; conta a menos de 10 pontos do limiar vai para o fim, porque trocaria
  logo de novo. Empate segue a fila. `CLAUDE_AUTO_STRATEGY=fila` volta para a ordem fixa e
  `CLAUDE_AUTO_MIN_HEADROOM` muda os 10 pontos.
- **Desbloqueio automático**: uma conta bloqueada por 429 volta sozinha para a fila quando chega uma
  leitura nova de uso (valores diferentes dos guardados no 429, ou seja, uma resposta nova da API)
  com todas as janelas abaixo do limiar. Se ela levar outro 429 em menos de 2 h, o limite era outro
  (semanal, de modelo) que a statusline não mostra, e a conta fica travada até o fim do bloqueio.
- **Uso real, lido na Anthropic**: a statusline só vê o que roda no Mac pelo `claude-auto`. A cada
  3 min, quando o `status` (a Brasa chama a cada 30 s) ou o wrapper rodam, o
  [`claude-usage`](./claude-usage) consulta o mesmo endereço do `/usage` do Claude Code para cada
  conta, com o login dela: no Mac, o que o Claude Code guarda no Keychain; na VM, o
  `~/.claude/.credentials.json`. Assim aparece também o gasto feito fora do `claude-auto` (app,
  outra máquina) e o número de contas paradas. O token só vai para a Anthropic, nunca na linha de
  comando, e nunca é gravado: vencido, o script pede ao próprio Claude Code o status do login (que
  o renova, quando renova) e, se continuar vencido, avisa.
- **Conta usada em outra máquina**: a orca também roda na VM orca-dev (`claude -p`), onde o login
  fica sempre em dia. Ela é lida primeiro lá (`ssh orca-dev ~/.local/bin/claude-usage`) e, se a VM
  não responder, no Mac. `CLAUDE_AUTO_REMOTES="orca:orca-dev"` é o padrão (vazio desliga);
  `CLAUDE_AUTO_LOCAL_USAGE=0` desliga a leitura pelo Keychain.
- **Orca reservada enquanto a orca-dev trabalha nela**: na VM não há troca de conta, e os
  `claude -p` param quando a orca enche. Mas a VM só é usada quando você pede, então a reserva
  vale só enquanto ela trabalha: a mesma leitura por ssh diz quando uma sessão de lá escreveu no
  histórico pela última vez (o Claude Code grava a cada passo), e até 30 min depois disso o Mac só
  usa a orca com as outras três cheias. Parada, a orca volta para a ordem normal. Uma sessão do Mac
  que esteja na orca quando a VM volta a trabalhar passa para outra conta no fim do turno assim que
  alguma tiver folga, quieta, como na troca antecipada; não troca com comando em segundo plano
  rodando e faz isso no máximo uma vez a cada 30 min por sessão. `CLAUDE_AUTO_RESERVED="orca"` é o
  padrão (vazio desliga); `CLAUDE_AUTO_RESERVE_IDLE` muda os 30 min.
- **Sessões em paralelo se espalham**: o Orca abre vários agentes de uma vez pelo `claude-auto`.
  Antes, todos caíam na primeira conta da ordem, que enchia rápido e mandava todos trocarem juntos
  (cada troca com o cache recomeçando do zero). Agora cada sessão aberta ocupa ~25 pontos da folga
  de uma conta (`CLAUDE_AUTO_SESSION_SHARE`): uma conta a 0% recebe até 3 sessões ao mesmo tempo,
  uma a 50%, só uma. Lotada, ela vai para depois das outras, e a próxima sessão abre na seguinte.
  A escolha usa uma trava curta, para sessões abertas no mesmo segundo se enxergarem.
- **Sem leitura**: leitura com mais de 15 min numa conta remota, ou de mais de 5 h numa do Mac
  (token vencido e ninguém usou pelo `claude-auto`), vira "sem leitura" no `status` e na Brasa,
  com o motivo, em vez de um 0% que pode ser falso.

Fila: `pessoal → ranielli → contato → orca` (mude com `CLAUDE_AUTO_PROFILES`; o limiar, com
`CLAUDE_AUTO_THRESHOLD`); é a ordem de desempate e a do modo `fila`. O `setup.sh` linka o script em
`~/.local/bin`.

```bash
claude-auto install          # uma vez: liga os hooks e encadeia a statusline no ~/.claude/settings.json
claude-auto                  # no lugar do `claude`; aceita as mesmas flags (ex.: claude-auto --continue)
claude-auto status           # uso conhecido, quando cada conta libera e a ordem de uso agora
claude-auto pull             # lê agora o uso real das contas na Anthropic
claude-auto unblock <conta>  # libera uma conta marcada como cheia
claude-auto doctor           # confere hooks, statusline, perfis, a leitura de cada conta e o Claude Code
scp claude-usage orca-dev:.local/bin/   # instala ou atualiza o leitor na VM
zsh tests/claude-auto/run.zsh           # testes, com claude, ssh e leitor falsos (nada real é tocado)
```

- **Religa sozinho**: se outro app (o Orca) reescrever o `settings.json` e tirar os hooks ou a
  statusline, o `claude-auto` religa antes de abrir uma sessão e, enquanto a Brasa estiver aberta,
  em até 30 s (a Brasa chama o `status` a cada 30 s). A statusline nova do outro app vira a cadeia
  chamada depois da do `claude-auto`, e o backup do `settings.json` sai no máximo um por dia.
  Depois de um `claude-auto uninstall`, nada é religado até o próximo `install`.
- **Claude Code novo**: o `claude-auto` depende de duas coisas não documentadas do Claude Code, o
  evento `StopFailure` e a variável interna `CLAUDE_CODE_RELAUNCH_HOME_TRUST`. A cada versão nova
  do binário ele confere se elas continuam lá; se sumirem, o `doctor` e a Brasa avisam.

Os testes da previsão da Brasa: `swiftc -parse-as-library brasa/Shared.swift
tests/brasa/forecast_test.swift -o /tmp/forecast_test && /tmp/forecast_test`.

Limitações:

- Só o CLI no terminal. O app desktop tem login próprio e fica de fora.
- A troca reinicia o processo: o cache de prompt começa frio na conta nova (a primeira resposta
  gasta mais) e os comandos em segundo plano morrem (a sessão é avisada e os reinicia).
- `CLAUDE_CODE_RELAUNCH_HOME_TRUST` é interno do Claude Code (visto até a 2.1.309). Se uma versão
  nova mudar o formato, a retomada na pasta pessoal volta a mostrar o aviso, sem outro efeito (se
  o nome sumir do binário, o `doctor` e a Brasa avisam).
- O prompt posicional (`claude-auto "faz X"`) só vai no primeiro launch; as retomadas não o reenviam.
- `--print` não é suportado: não há sessão interativa para retomar.
- Entre o Orca reescrever o `settings.json` e o reparo (até 30 s com a Brasa aberta, ou na próxima
  sessão), a troca antecipada fica parada.

#### Brasa: o Mac e as contas na barra de menus

*Tudo na brasa.* O [Brasa](./brasa) é um app nativo (SwiftUI) de barra de menus, no estilo do
[Disco](https://github.com/RogerBrusamarello/disco-macos), que junta duas coisas: o Mac trabalhando
(a brasa: CPU, memória e disco) e as contas Claude do `claude-auto` (os espetos, na seção
**Rodízio**: *passa a próxima*). Substitui o Disco para acompanhar CPU, memória e disco e os apps que
mais usam memória; a limpeza de temporários e a análise do que ocupa o disco continuam só no Disco.
Também substitui o [LinearMouse](https://linearmouse.app), que só servia para deixar a rolagem do
trackpad e a do mouse em sentidos diferentes.

- **Barra de menus:** a chama da Brasa dentro de um anel, em traço de sistema (16 pt, o peso dos
  ícones do sistema): o anel é o uso da conta em uso, e o número ao lado (`53%`) usa a fonte do
  relógio, alinhado pelos dígitos e encostado no ícone, com largura de dois dígitos para não pular.
  Com todas as contas cheias, o anel fica tracejado. Nos Ajustes dá para trocar pelo espeto (um
  pedaço por conta: cheio é conta com folga, vazado é conta cheia) e ligar blocos de **CPU**,
  **RAM** e **HD** (rótulo em cima, valor embaixo). Se o claude-auto parar de responder, o ícone
  fica a 35%, como item desabilitado. Passando o mouse, aparece o resumo das contas e do Mac.
- **Ícone do app:** uma brasa, com a chama sobre três carvões acesos, desenhada pelo próprio app
  (`--icon`) e convertida no `.icns` pelo `build.sh`.
- **Painel** (clique no ícone ou no widget): uma grade de módulos de vidro, como a Central de
  Controle do macOS 26. Os módulos abrem fechados; clicar abre o detalhe dentro deles, como os de
  Wi-Fi e Som.
  - **Contas:** um anel por conta, com o uso no centro, o tempo até zerar ("até HH:MM" se cheia,
    "5h livres" com a janela fechada) e a nota (em uso, próxima, ativa). A marca no anel é o ritmo
    ideal: onde o uso estaria se fosse uniforme até a janela zerar. Clicar num anel abre o detalhe:
    o gráfico de queima da janela de 5h (uso, guia de uso uniforme tracejada, limiar e a projeção
    pontilhada até ele), o ritmo em frase ("+22 pts/h, 2× o ritmo que dura até zerar"), a semana, o
    e-mail logado e **Liberar agora** quando a conta está bloqueada. Conta sem leitura recente
    mostra o anel pontilhado com "?", "sem leitura" e o motivo (há quanto tempo, "token vencido",
    "orca-dev fora"), e fica fora da contagem "com folga"; o detalhe diz de onde veio o número
    ("Uso lido na Anthropic", "via orca-dev").
  - **CPU, Memória e Disco:** um anel cada, com carga, pressão de memória (que dá o estado) e o
    espaço livre como o Finder conta.
  - **Agora:** a frase de estado do claude-auto ("Pessoal enche por volta de 14:40 · Depois vem
    Ranielli"; "Todas as contas estão cheias · Contato libera às 15:10").
  - **Mais usam memória:** os 3 apps que mais usam memória (abre para 5, com o swap), somando os
    processos auxiliares e o que foi aberto no terminal de cada app, com um ⓧ para **forçar o
    encerramento** (pede confirmação). A lista só é lida com o painel aberto.
  - Teclado: **⌘,** abre os Ajustes, **Esc** fecha o painel.
- **Cores com forma:** azul para folga, laranja com triângulo para atenção (perto do limiar ou
  gastando mais rápido do que a janela aguenta), vermelho com × e anel tracejado para cheia, anel
  vazio para janela fechada, anel pontilhado com "?" para sem leitura. O estado se lê sem distinguir
  cores. A cor da marca (brasa) fica só no
  ícone do app e nas ações.
- **Previsão:** o ritmo da última hora dentro da janela de 5h. Só aparece se o uso subiu ao menos
  2 pontos em 10 min ou mais e se o limiar chega antes de a janela zerar.
- **Saúde da instalação:** quando falta um hook, a statusline ou algo do Claude Code de que o
  `claude-auto` depende, o painel abre com o aviso "claude-auto precisa de atenção" e o que está
  faltando, com **Religar** quando é hook ou statusline. Uma notificação avisa quando o problema
  aparece e quando o `claude-auto` religou sozinho ("Outro app (o Orca?) tinha tirado: …").
- **Avisos:** notificação ~20 min antes de uma conta em uso encher (uma vez por janela, dizendo
  qual vem depois), quando ela enche, quando libera e quando o `claude-auto` passa a sessão para
  outra conta. Enquanto a orca-dev trabalha na orca, ela avisa mesmo sem sessão no Mac ("Orca
  chega a 95% às 19:24 na orca-dev"), porque lá o trabalho para quando ela enche. No painel, a
  orca mostra "da orca-dev" nessas horas, e o detalhe diz se a reserva vale agora ("A orca-dev
  está trabalhando nela") ou não ("parada desde 06:08. Agora o Mac usa normalmente").
- **Widget Rodízio** (Central de Notificações ou mesa: **Editar Widgets…** → *Brasa*):
  - **pequeno:** quantas contas têm folga (`3/4`), uma coluna por conta e a próxima da fila;
  - **médio:** o mesmo resumo e uma linha por conta, com a barra e o % (ou "até HH:MM" se cheia);
  - **grande:** a ordem de uso e um cartão por conta, com e-mail, estado, barra, linha do
    histórico e o horário em que a janela zera (ou "enche HH:MM", quando há previsão).

  Clicar no widget abre o painel. O app grava o retrato em
  `~/Library/Application Support/Brasa/widget.json` e pede para o widget redesenhar quando muda
  algo que se vê de relance (folga, conta em uso, próxima, faixa de 5 pontos de uso); o widget também
  vira sozinho quando uma conta libera ou uma janela zera, e no máximo a cada 15 min. Sem certificado
  de desenvolvedor, o widget é assinado ad-hoc e lê esse arquivo por uma exceção só de leitura do
  sandbox (o App Group, que o Disco usa, exige certificado). Se ele não aparecer na galeria, adicione
  uma Apple ID em Xcode → Settings → Accounts e rode o `build.sh` de novo: ele assina com o
  certificado "Apple Development" quando existe um.
- **Rolagem por aparelho:** trackpad com rolagem natural e mouse de roda com rolagem tradicional.
  O macOS tem uma chave só de "Rolagem natural" para os dois; o Brasa inverte o aparelho que fica
  do outro jeito (com a chave desligada, inverte o trackpad; ligada, o mouse). Trackpad e Magic
  Mouse rolam em eventos contínuos e a roda do mouse em linhas, e é assim que ele distingue. Usa
  um event tap, que precisa da permissão de **Acessibilidade**. Como o Brasa é assinado ad-hoc, a
  identidade muda a cada `build.sh` e a permissão precisa ser dada de novo: ligar de novo a entrada
  antiga não basta, porque ela guarda a assinatura do build anterior. Apague a entrada (com − na
  lista ou `tccutil reset Accessibility com.rannimontagna.brasa`), reabra o Brasa e ligue no pedido
  que aparece. Os Ajustes mostram o estado e um botão para abrir a lista, e o estado também fica
  em `~/Library/Application Support/Brasa/scroll.json`. Com o LinearMouse aberto o Brasa não
  inverte nada (os dois juntos inverteriam duas vezes) e oferece fechá-lo.
- **Ajustes** (engrenagem ou ⌘, no painel), numa janela própria: o que aparece na barra, com
  prévia; rolagem por aparelho; avisos; **Abrir junto com o Mac**.

As contas vêm de `claude-auto status --json` (o app atualiza quando o claude-auto grava algo em
`~/.local/state/claude-auto` e a cada 30 s); o Mac é lido direto do sistema a cada 5 s. O histórico
fica em `~/Library/Application Support/Brasa/history.json`. Precisa do Xcode.

```bash
bash brasa/build.sh   # compila app e widget, gera o ícone, instala em ~/Applications e abre no login
```

**Certificado local (uma vez por Mac):** sem certificado de desenvolvedor, o `build.sh` assinaria
ad-hoc, e cada build mudaria a identidade do app (o macOS esquece a permissão de Acessibilidade).
Com um certificado autoassinado chamado **Brasa Local**, a identidade fica a mesma entre builds:

1. Acesso às Chaves → menu **Acesso às Chaves → Assistente de Certificado → Criar um Certificado…**
2. Nome **Brasa Local**, Tipo de Identidade **Raiz Autoassinada**, Tipo de Certificado
   **Assinatura de Código** → Criar.
3. No primeiro `build.sh`, o macOS pergunta se o `codesign` pode usar a chave: **Permitir Sempre**.
4. Uma última vez, apague a entrada antiga em Acessibilidade
   (`tccutil reset Accessibility com.rannimontagna.brasa`) e ligue o Brasa no pedido. Daí em
   diante, os builds mantêm a permissão.

O `build.sh` diz com o que assinou (`assinado com: Brasa Local`). O certificado vale um ano (o
deste Mac, criado em 23/10/2026, vence em 23/10/2027): ao vencer, crie outro com o mesmo nome e
repita o passo 4 uma vez.

O `build.sh` também tira as versões anteriores (ClaudeAutoBar e Rodízio) e traz o histórico e os
ajustes do Rodízio. Código: `App.swift` (ajustes, marca, prévias), `Panel.swift` (barra e painel),
`Mac.swift` (CPU, memória, disco e apps), `Accounts.swift` (seção Rodízio), `Shared.swift` (modelo
e desenho em comum com o widget), `WidgetViews.swift` e `Widget.swift` (widget).

Para conferir sem a barra: `~/Applications/Brasa.app/Contents/MacOS/Brasa --stats` imprime as leituras
do Mac (para comparar com o Monitor de Atividade), e `--snapshot paineis.png`, `--widgets widgets.png`,
`--menubar barra.png` (o item da barra ampliado, ao lado do relógio) e `--icon icone.png` desenham o visual. "Sair" no painel fecha até o próximo login. Para remover de
vez: `launchctl bootout gui/$(id -u)/com.rannimontagna.brasa` e apague o `.plist` em
`~/Library/LaunchAgents` e o app em `~/Applications`.

## Personalizando

- **Apps/pacotes**: edite o [`Brewfile`](./Brewfile) e rode `brew bundle`
- **Shell**: edite o [`zshrc`](./zshrc) (é symlink, mudanças valem na hora)

## Dica: scroll estilo Linux

O macOS vem com "rolagem natural" ligada. Para inverter (como no Linux/Windows):
Ajustes do Sistema → Trackpad / Mouse → desmarque **Rolagem natural**.
A chave vale para o trackpad e o mouse juntos; para ter o trackpad natural e o mouse tradicional,
o [Brasa](#brasa-o-mac-e-as-contas-na-barra-de-menus) inverte o aparelho que fica do outro jeito
(Ajustes do Brasa → Rolagem). Ele substituiu o LinearMouse, que saiu do Brewfile.

## Dica: print de uma região, sem app

O print nativo faz o que o Shottr fazia aqui (recortar uma região e copiar ou salvar), sem
outro app aberto; o Shottr saiu do Brewfile.

| Para | Atalho |
|---|---|
| Região → área de transferência | **⌃⌘⇧4** (ou ⌘⇧4 segurando ⌃ ao soltar o mouse) |
| Região → arquivo (Mesa) | **⌘⇧4**; a miniatura no canto dá para arrastar para um app ou clicar para anotar |
| Pasta, temporizador, tela inteira | **⌘⇧5** → Opções |

Os atalhos mudam em Ajustes do Sistema → Teclado → Atalhos de Teclado → Capturas de Tela.

## Gotchas de macOS (scripts shell)

O macOS usa ferramentas **BSD**, não GNU — alguns comandos diferem do Linux e
quebram scripts que passaram só no CI Linux. Os que mais mordem:

- **`sed -i`** — no macOS exige sufixo de backup (`sed -i '' 's/…/'`); no Linux é
  `sed -i 's/…/'`. Para portabilidade, evite `sed -i` e use **`perl -i -pe 's/…/'`**
  (idêntico nos dois SOs, sem deixar arquivo `.bak`).
- Outros BSD-vs-GNU: `readlink -f`, `date -d`, `stat -c`, `xargs -r`. Se precisar das
  versões GNU: `brew install coreutils gnu-sed` (ficam com prefixo `g`: `gsed`, `gdate`).
