# mac-setup

Script de configuração de um **Mac novo** para desenvolvimento (Apple Silicon).
Instala as ferramentas, configura Git e SSH, e prepara o ambiente Node — tudo com um comando.

[![Licença: MIT](https://img.shields.io/github/license/raniellimontagna/mac-setup)](LICENSE)

## Sumário

- [O que ele faz](#o-que-ele-faz)
- [Como usar num Mac novo](#como-usar-num-mac-novo)
- [Depois de rodar](#depois-de-rodar)
- [Repos privados de empresa](#repos-privados-de-empresa)
- [Múltiplas contas do Claude Code](#múltiplas-contas-do-claude-code)
- [Personalizando](#personalizando)
- [Dicas](#dicas): economia de tokens, scroll estilo Linux, print de região, gotchas de shell no macOS
- [Licença](#licença)

## O que ele faz

- Instala o **Xcode Command Line Tools** (se faltar)
- Instala o **Homebrew**
- Instala pacotes e apps via [`Brewfile`](./Brewfile):
  - **Linha de comando:** `git`, `gh`, AWS CLI, `fnm`, `uv`, Python 3.13, Go, llama.cpp, `rtk`, Starship e os plugins do zsh
  - **CLI modernas:** fzf, zoxide, eza, bat, fd, ripgrep, jq, lazygit, git-delta, btop
  - **Mobile:** watchman, CocoaPods, OpenJDK 17
  - **Apps de desenvolvimento:** OrbStack, Android Studio, VS Code, Ghostty, Warp, Chrome, Bruno, DBeaver, Tailscale, Ollama, LM Studio, Grok Build (CLI da xAI)
  - **Utilitários:** Keka, Raycast, Stats, Rectangle, Obsidian
  - **Fora de desenvolvimento:** Spotify, Bitwarden, WhatsApp, Discord, Telegram, Steam
  - Fonte JetBrains Mono Nerd Font (ícones do prompt)
- Configura o **Git** (nome, email e defaults sensatos)
- Gera uma **chave SSH** (`ed25519`) e o `~/.ssh/config` usando o keychain do macOS
- Instala o [`.zshrc`](./zshrc), o [`starship.toml`](./starship.toml) e a [config do Ghostty](./ghostty-config) como symlinks
  - **Starship** no prompt (branch git, versão do Node, cores) + autosuggestions e syntax-highlighting
  - **Perfis do Claude Code** (`claude-pessoal` + um por conta de trabalho) — múltiplas contas com
    ambientes isolados — veja [Múltiplas contas do Claude Code](#múltiplas-contas-do-claude-code)
- Tenta clonar o repositório **privado** `raniellimontagna/brasa` (`claude-auto` e o app Brasa);
  sem acesso a ele, o setup só mostra um aviso e segue — veja [Troca automática de conta e o Brasa](#troca-automática-de-conta-e-o-brasa)
- Configura **gitignore global** ([`gitignore_global`](./gitignore_global)) e **aliases** do git (`st`, `co`, `lg`, `cm`...)
- Instala o **Node LTS** via `fnm`, habilita **pnpm** via corepack e instala o `eas-cli` (Expo)
- Instala o **Graphify** via `uv`
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

- **Maestri** — canvas multi-agente; instalado pelo site. Dois scripts montam times prontos e
  precisam rodar **dentro de um terminal do Maestri**:
  - [`maestri-team.sh`](./maestri-team.sh) — `Batuta` (Codex) planeja e coordena, os executores
    `Forja1..N` (Codex; `EXEC_COUNT` define quantos) implementam e `Sonar` (Claude Code) revisa.
    Uso: `./maestri-team.sh [DIR_DO_PROJETO] ["TAREFA INICIAL"]`, com o toggle **Maestro** ativo
    no terminal. Os agentes rodam sem pedir confirmação: use num diretório com git limpo.
  - [`maestri-team-codex-grok.sh`](./maestri-team-codex-grok.sh) — Codex orquestra e Grok executa.
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

### Troca automática de conta e o Brasa

A troca automática de conta (`claude-auto`) e o Brasa (painel na barra de menus do Mac e na
bandeja do Windows com o uso das contas e da máquina) moram no repositório `raniellimontagna/brasa`,
que é **privado** (não abre para quem não tem acesso). O [`setup.sh`](./setup.sh) tenta clonar esse
repo via SSH em `~/Projetos/pessoal/brasa` (ou atualizá-lo, se já existir) e linka o `claude-auto`
em `~/.local/bin`. Se o clone falhar (sem acesso ao repo ou sem chave SSH no GitHub), o setup só
mostra um aviso e continua; nada mais depende dele. O app do Brasa só é compilado e instalado
quando ainda não existe, ou com `bash setup.sh --brasa`. Como usar e como funciona estão no
README de lá.

## Personalizando

- **Apps/pacotes**: edite o [`Brewfile`](./Brewfile) e rode `brew bundle`
- **Shell**: edite o [`zshrc`](./zshrc) (é symlink, mudanças valem na hora)

## Dicas

### Economia de tokens (agentes de IA)

Duas alavancas que reduzem consumo de token em sessões com agentes (Claude Code, Codex...):

- **rtk** (Rust Token Killer — já no `Brewfile`) — comprime a **saída de comandos** que o agente lê.
  Prefixe: `rtk git status`, `rtk pnpm install`, `rtk tsc`. Veja economia com `rtk gain`.
- **caveman** — plugin/skill que faz o **próprio agente responder comprimido** (~65% menos tokens de
  saída). **Não é brew** — instala dentro de cada agente:
  - **Claude Code:** `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman` (auto-ativa)
  - **Codex:** `npx skills add JuliusBrussee/caveman -a codex` (ative com `/caveman` uma vez por sessão)
  - Níveis: `/caveman lite` (tira só formalidades) → default → `full` → `ultra`. Comece no `lite`.

### Scroll estilo Linux

O macOS vem com "rolagem natural" ligada. Para inverter (como no Linux/Windows):
Ajustes do Sistema → Trackpad / Mouse → desmarque **Rolagem natural**.
A chave vale para o trackpad e o mouse juntos; para ter o trackpad natural e o mouse tradicional,
o Brasa (do repositório privado `raniellimontagna/brasa`, ver acima) inverte o aparelho que fica do outro jeito
(Ajustes do Brasa → Rolagem). Ele substituiu o LinearMouse, que saiu do Brewfile.

### Print de uma região, sem app

O print nativo faz o que o Shottr fazia aqui (recortar uma região e copiar ou salvar), sem
outro app aberto; o Shottr saiu do Brewfile.

| Para | Atalho |
|---|---|
| Região → área de transferência | **⌃⌘⇧4** (ou ⌘⇧4 segurando ⌃ ao soltar o mouse) |
| Região → arquivo (Mesa) | **⌘⇧4**; a miniatura no canto dá para arrastar para um app ou clicar para anotar |
| Pasta, temporizador, tela inteira | **⌘⇧5** → Opções |

Os atalhos mudam em Ajustes do Sistema → Teclado → Atalhos de Teclado → Capturas de Tela.

### Gotchas de macOS (scripts shell)

O macOS usa ferramentas **BSD**, não GNU — alguns comandos diferem do Linux e
quebram scripts que passaram só no CI Linux. Os que mais mordem:

- **`sed -i`** — no macOS exige sufixo de backup (`sed -i '' 's/…/'`); no Linux é
  `sed -i 's/…/'`. Para portabilidade, evite `sed -i` e use **`perl -i -pe 's/…/'`**
  (idêntico nos dois SOs, sem deixar arquivo `.bak`).
- Outros BSD-vs-GNU: `readlink -f`, `date -d`, `stat -c`, `xargs -r`. Se precisar das
  versões GNU: `brew install coreutils gnu-sed` (ficam com prefixo `g`: `gsed`, `gdate`).

## Licença

Distribuído sob a [Licença MIT](LICENSE).
