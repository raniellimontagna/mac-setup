#!/opt/homebrew/bin/python3
"""contexto: diz qual conta usar a partir da pasta da sessão.

O contexto é o `workspace` do `.ai-memory.toml` mais próximo, subindo a
partir da pasta e parando antes da home. O mapa
(`$CONTEXTOS_MAPA` ou `~/.config/contextos/mapa.toml`) liga cada workspace
às contas de cada serviço e lista, em `[_bloqueio]`, as pastas onde o
Executor não pode ser usado.

Uso:
  contexto [--dir DIR] [--servico SERVICO]
  contexto hook        # PreToolUse do Claude/Codex: JSON do hook no stdin

Saída: JSON em stdout. Códigos: 0 ok, 3 sem-contexto, 4 bloqueado,
5 fora-do-mapa, 6 mapa-invalido. No modo hook: 2 bloqueia a ferramenta.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tomllib
from pathlib import Path
from typing import TextIO

MARCADOR = ".ai-memory.toml"
PREFIXO_EXECUTOR = "mcp__executor__"


class SemContexto(Exception):
    codigo, erro = 3, "sem-contexto"


class Bloqueado(Exception):
    codigo, erro = 4, "bloqueado"


class ForaDoMapa(Exception):
    codigo, erro = 5, "fora-do-mapa"

    def __init__(self, workspace: str, servico: str):
        super().__init__(f"{workspace}/{servico}")
        self.workspace, self.servico = workspace, servico


class MapaInvalido(Exception):
    codigo, erro = 6, "mapa-invalido"


def _dentro(p: Path, base: Path) -> bool:
    return p == base or base in p.parents


def achar_workspace(dir: Path, raiz: Path) -> str | None:
    dir, raiz = dir.resolve(), raiz.resolve()
    if raiz not in dir.parents:
        return None
    atual = dir
    while atual != raiz:
        marcador = atual / MARCADOR
        if marcador.is_file():
            try:
                dados = tomllib.loads(marcador.read_text())
            except (OSError, tomllib.TOMLDecodeError) as e:
                raise MapaInvalido(f"marcador ilegível: {marcador}: {e}") from e
            workspace = dados.get("workspace")
            if isinstance(workspace, str) and workspace:
                return workspace
        atual = atual.parent
    return None


def caminho_mapa(raiz: Path) -> Path:
    return Path(os.environ.get("CONTEXTOS_MAPA") or raiz / ".config/contextos/mapa.toml")


def carregar_mapa(caminho: Path) -> dict:
    try:
        mapa = tomllib.loads(caminho.read_text())
    except (OSError, tomllib.TOMLDecodeError) as e:
        raise MapaInvalido(f"{caminho}: {e}") from e
    pastas = mapa.get("_bloqueio", {}).get("pastas", [])
    if not isinstance(pastas, list) or not all(isinstance(p, str) for p in pastas):
        raise MapaInvalido(f"{caminho}: _bloqueio.pastas precisa ser lista de texto")
    return mapa


def _expandir(pasta: str, raiz: Path) -> Path:
    if pasta == "~":
        return raiz
    if pasta.startswith("~/"):
        return raiz / pasta[2:]
    return Path(pasta)


def esta_bloqueado(dir: Path, mapa: dict, raiz: Path) -> bool:
    dir = dir.resolve()
    pastas = mapa.get("_bloqueio", {}).get("pastas", [])
    return any(_dentro(dir, _expandir(p, raiz).resolve()) for p in pastas)


def resolver(dir: Path, servico: str | None, mapa: dict, raiz: Path) -> dict:
    if esta_bloqueado(dir, mapa, raiz):
        raise Bloqueado(str(dir))
    workspace = achar_workspace(dir, raiz)
    if workspace is None:
        raise SemContexto(str(dir))
    if servico is None:
        return {"workspace": workspace}
    secao = mapa.get(workspace) if not workspace.startswith("_") else None
    if not isinstance(secao, dict) or servico not in secao:
        raise ForaDoMapa(workspace, servico)
    valor = secao[servico]
    if isinstance(valor, str):
        conta, pasta_drive = valor, None
    elif isinstance(valor, dict) and isinstance(valor.get("conta"), str):
        conta, pasta_drive = valor["conta"], valor.get("pasta_drive")
    else:
        raise MapaInvalido(f"[{workspace}] {servico}: use \"conta\" ou {{ conta = ..., pasta_drive = ... }}")
    return {"workspace": workspace, "servico": servico, "conta": conta, "pasta_drive": pasta_drive}


def _imprimir(dados: dict) -> None:
    print(json.dumps(dados, ensure_ascii=False))


def _hook(stdin: TextIO, raiz: Path) -> int:
    try:
        evento = json.loads(stdin.read())
    except Exception as e:
        print(f"contexto hook: stdin inválido, bloqueando por segurança ({e})", file=sys.stderr)
        return 2
    ferramenta = evento.get("tool_name", "") if isinstance(evento, dict) else ""
    if not (isinstance(ferramenta, str) and ferramenta.startswith(PREFIXO_EXECUTOR)):
        return 0
    try:
        cwd = Path(evento["cwd"])
        if esta_bloqueado(cwd, carregar_mapa(caminho_mapa(raiz)), raiz):
            print(
                f"Executor bloqueado nesta pasta ({cwd}): Lemon e consórcio não usam o Executor.",
                file=sys.stderr,
            )
            return 2
    except Exception as e:
        print(f"contexto hook: falha ao conferir o bloqueio, bloqueando por segurança ({e})", file=sys.stderr)
        return 2
    return 0


def main(argv: list[str], stdin: TextIO, raiz: Path = Path.home()) -> int:
    if argv[:1] == ["hook"]:
        return _hook(stdin, raiz)
    parser = argparse.ArgumentParser(prog="contexto", description="Conta a usar pela pasta da sessão.")
    parser.add_argument("--dir", type=Path, default=None, help="pasta da sessão (padrão: a atual)")
    parser.add_argument("--servico", default=None, help="serviço, ex.: google")
    args = parser.parse_args(argv)
    dir = args.dir if args.dir is not None else Path.cwd()
    try:
        _imprimir(resolver(dir, args.servico, carregar_mapa(caminho_mapa(raiz)), raiz))
        return 0
    except ForaDoMapa as e:
        _imprimir({"erro": e.erro, "workspace": e.workspace, "servico": e.servico})
        return e.codigo
    except MapaInvalido as e:
        _imprimir({"erro": e.erro, "detalhe": str(e)})
        return e.codigo
    except (SemContexto, Bloqueado) as e:
        _imprimir({"erro": e.erro, "dir": str(e)})
        return e.codigo


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], sys.stdin))
