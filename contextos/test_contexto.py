"""Testes do `contexto`: resolve a conta pelo workspace da pasta e bloqueia
o Executor nas pastas fechadas.

Rodar: /opt/homebrew/bin/python3 -m unittest -v test_contexto
"""

import contextlib
import io
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import contexto


class Base(unittest.TestCase):
    def setUp(self):
        self.raiz = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, self.raiz, ignore_errors=True)
        self.mapa = self.raiz / "mapa.toml"
        env = mock.patch.dict(os.environ, {"CONTEXTOS_MAPA": str(self.mapa)})
        env.start()
        self.addCleanup(env.stop)
        self.escrever_mapa('[_bloqueio]\npastas = []\n')
        self.lemon = self.raiz / "Projetos/empresa/lemon"

    def escrever_mapa(self, texto):
        self.mapa.write_text(texto)

    def bloquear_lemon(self, extra=""):
        self.escrever_mapa(f'[_bloqueio]\npastas = ["{self.lemon}"]\n{extra}')

    def marcador(self, pasta, workspace):
        pasta.mkdir(parents=True, exist_ok=True)
        (pasta / ".ai-memory.toml").write_text(f'workspace = "{workspace}"\n')

    def pasta(self, rel):
        p = self.raiz / rel
        p.mkdir(parents=True, exist_ok=True)
        return p

    def rodar(self, *argv, stdin=""):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            codigo = contexto.main(list(argv), io.StringIO(stdin), raiz=self.raiz)
        texto = out.getvalue().strip()
        return codigo, (json.loads(texto) if texto else None)

    def hook(self, cwd, tool_name):
        return self.rodar("hook", stdin=json.dumps({"cwd": str(cwd), "tool_name": tool_name}))[0]


class Workspace(Base):
    def test_workspace_da_pasta_mais_proxima(self):
        self.marcador(self.raiz / "Projetos/pessoal", "pessoal")
        sub = self.pasta("Projetos/pessoal/second-brain/sub")
        self.assertEqual(self.rodar("--dir", str(sub)), (0, {"workspace": "pessoal"}))

    def test_marcador_mais_proximo_ganha(self):
        self.marcador(self.raiz / "Projetos/empresa", "x")
        self.marcador(self.raiz / "Projetos/empresa/atto", "atto")
        sub = self.pasta("Projetos/empresa/atto/repo")
        self.assertEqual(self.rodar("--dir", str(sub)), (0, {"workspace": "atto"}))

    def test_raiz_nao_conta(self):
        self.marcador(self.raiz, "casa")
        for d in (self.raiz, self.pasta("Documentos")):
            codigo, saida = self.rodar("--dir", str(d))
            self.assertEqual(codigo, 3, d)
            self.assertEqual(saida["erro"], "sem-contexto")

    def test_fora_da_raiz_e_sem_contexto(self):
        fora = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, fora, ignore_errors=True)
        self.marcador(fora, "x")
        codigo, saida = self.rodar("--dir", str(fora))
        self.assertEqual(codigo, 3)
        self.assertEqual(saida["erro"], "sem-contexto")


class Bloqueio(Base):
    def test_pasta_bloqueada_e_subpasta(self):
        self.bloquear_lemon()
        for d in (self.pasta("Projetos/empresa/lemon"), self.pasta("Projetos/empresa/lemon/repo/x")):
            codigo, saida = self.rodar("--dir", str(d))
            self.assertEqual(codigo, 4, d)
            self.assertEqual(saida["erro"], "bloqueado")

    def test_bloqueio_vence_marcador(self):
        self.bloquear_lemon()
        self.marcador(self.lemon, "lemon")
        self.assertEqual(self.rodar("--dir", str(self.lemon))[0], 4)

    def test_prefixo_nao_bloqueia_vizinha(self):
        self.bloquear_lemon()
        vizinha = self.raiz / "Projetos/empresa/lemon-outro"
        self.marcador(vizinha, "x")
        self.assertEqual(self.rodar("--dir", str(vizinha)), (0, {"workspace": "x"}))

    def test_symlink_para_bloqueada(self):
        self.bloquear_lemon()
        repo = self.pasta("Projetos/empresa/lemon/repo")
        atalho = self.raiz / "atalho"
        atalho.symlink_to(repo)
        self.assertEqual(self.rodar("--dir", str(atalho))[0], 4)

    def test_til_expande_no_bloqueio(self):
        self.escrever_mapa('[_bloqueio]\npastas = ["~/Projetos/empresa/lemon"]\n')
        self.assertEqual(self.rodar("--dir", str(self.pasta("Projetos/empresa/lemon/repo")))[0], 4)


class Conta(Base):
    def test_conta_simples(self):
        self.escrever_mapa('[_bloqueio]\npastas = []\n[atto]\ngoogle = "atto"\n')
        self.marcador(self.raiz / "Projetos/empresa/atto", "atto")
        codigo, saida = self.rodar("--dir", str(self.raiz / "Projetos/empresa/atto"), "--servico", "google")
        self.assertEqual(codigo, 0)
        self.assertEqual(saida, {"workspace": "atto", "servico": "google", "conta": "atto", "pasta_drive": None})

    def test_conta_com_pasta(self):
        self.escrever_mapa(
            '[_bloqueio]\npastas = []\n'
            '[grupo-tala]\ngoogle = { conta = "atto", pasta_drive = "abc123" }\n'
        )
        self.marcador(self.raiz / "Projetos/empresa/grupo-tala", "grupo-tala")
        codigo, saida = self.rodar("--dir", str(self.raiz / "Projetos/empresa/grupo-tala"), "--servico", "google")
        self.assertEqual(codigo, 0)
        self.assertEqual(saida["conta"], "atto")
        self.assertEqual(saida["pasta_drive"], "abc123")

    def test_servico_fora_do_mapa(self):
        self.escrever_mapa('[_bloqueio]\npastas = []\n[atto]\ngoogle = "atto"\n')
        self.marcador(self.raiz / "Projetos/empresa/atto", "atto")
        codigo, saida = self.rodar("--dir", str(self.raiz / "Projetos/empresa/atto"), "--servico", "dokploy")
        self.assertEqual(codigo, 5)
        self.assertEqual(saida["erro"], "fora-do-mapa")
        self.assertEqual(saida["servico"], "dokploy")
        self.assertEqual(saida["workspace"], "atto")

    def test_workspace_sem_secao(self):
        self.marcador(self.raiz / "Projetos/empresa/beela", "beela")
        codigo, saida = self.rodar("--dir", str(self.raiz / "Projetos/empresa/beela"), "--servico", "google")
        self.assertEqual(codigo, 5)
        self.assertEqual(saida["erro"], "fora-do-mapa")

    def test_mapa_ausente(self):
        self.mapa.unlink()
        self.marcador(self.raiz / "Projetos/pessoal", "pessoal")
        codigo, saida = self.rodar("--dir", str(self.raiz / "Projetos/pessoal"))
        self.assertEqual(codigo, 6)
        self.assertEqual(saida["erro"], "mapa-invalido")
        self.assertIn("detalhe", saida)


class Hook(Base):
    def test_hook_bloqueia_executor_em_pasta_bloqueada(self):
        self.bloquear_lemon()
        repo = self.pasta("Projetos/empresa/lemon/repo")
        self.assertEqual(self.hook(repo, "mcp__executor__execute"), 2)

    def test_hook_libera_executor_fora_do_bloqueio(self):
        self.bloquear_lemon()
        self.marcador(self.raiz / "Projetos/pessoal", "pessoal")
        self.assertEqual(self.hook(self.raiz / "Projetos/pessoal", "mcp__executor__execute"), 0)

    def test_hook_ignora_outras_ferramentas(self):
        self.bloquear_lemon()
        self.assertEqual(self.hook(self.pasta("Projetos/empresa/lemon"), "Bash"), 0)

    def test_hook_fecha_com_mapa_invalido(self):
        self.escrever_mapa("[_bloqueio\npastas = ")
        self.assertEqual(self.hook(self.pasta("Projetos/pessoal"), "mcp__executor__execute"), 2)

    def test_hook_fecha_com_stdin_invalido(self):
        self.assertEqual(self.rodar("hook", stdin="nao é json")[0], 2)


if __name__ == "__main__":
    unittest.main()
