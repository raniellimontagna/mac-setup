# mac-setup

Script de configuração de um **Mac novo** para desenvolvimento (Apple Silicon).
Instala as ferramentas, configura Git e SSH, e prepara o ambiente Node — tudo com um comando.

## O que ele faz

- Instala o **Xcode Command Line Tools** (se faltar)
- Instala o **Homebrew**
- Instala pacotes e apps via [`Brewfile`](./Brewfile): `git`, `gh`, `fnm`, Starship, plugins do zsh, Nerd Font, OrbStack, VS Code, Ghostty, Chrome, Mos
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

## Personalizando

- **Apps/pacotes**: edite o [`Brewfile`](./Brewfile) e rode `brew bundle`
- **Shell**: edite o [`zshrc`](./zshrc) (é symlink, mudanças valem na hora)

## Dica: scroll estilo Linux

O macOS vem com "rolagem natural" ligada. Para inverter (como no Linux/Windows):
Ajustes do Sistema → Trackpad / Mouse → desmarque **Rolagem natural**.
O app **Mos** (no Brewfile) permite configurar mouse e trackpad separadamente.
