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
  Ex.: `bash clone-org.sh attodevlabs ~/Projetos/empresa/atto`. Rodar de novo dá `git pull` nos existentes.
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
- **[`ai-clis.sh`](./ai-clis.sh)** — instala os CLIs de IA (Claude Code, Codex, Gemini, opencode)
  pelos canais oficiais. O app **[Superset](https://superset.com)** (hub que agrupa esses agentes)
  é instalado à parte pelo site — não é o `superset` do Homebrew (aquele é o Apache Superset de BI).

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
  go env -w GOPRIVATE="github.com/esperto-sistemas,github.com/quadralize,github.com/attodevlabs,github.com/ZenPush"
  ```
- **GitHub Packages privado** (`@attodevlabs/*` via pnpm) — precisa de token com escopo `read:packages`:
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

## Personalizando

- **Apps/pacotes**: edite o [`Brewfile`](./Brewfile) e rode `brew bundle`
- **Shell**: edite o [`zshrc`](./zshrc) (é symlink, mudanças valem na hora)

## Dica: scroll estilo Linux

O macOS vem com "rolagem natural" ligada. Para inverter (como no Linux/Windows):
Ajustes do Sistema → Trackpad / Mouse → desmarque **Rolagem natural**.
O app **LinearMouse** (no Brewfile) permite configurar scroll por dispositivo
(mouse vs trackpad separados) e desativar a aceleração do ponteiro.
