"""Configuração e utilitários compartilhados pelos scripts de coleta.

Todos os arquivos baixados vão para dados/brutos/ sem alteração, e cada
download é registrado em dados/brutos/fontes.json (URL, órgão, data de coleta,
versão, licença e SHA-256), que depois vira dados/brutos/FONTES.md.
"""
from __future__ import annotations

import hashlib
import json
from datetime import date
from pathlib import Path

import requests

RAIZ = Path(__file__).resolve().parents[2]
BRUTOS = RAIZ / "dados" / "brutos"
MANIFESTO = BRUTOS / "fontes.json"

# Recorte: microrregião de Itabira (IBGE, código 31031), que inclui João Monlevade.
UF = "MG"
COD_UF = 31
COD_MICRORREGIAO = 31031
NOME_RECORTE = "Microrregião de Itabira (MG)"

# Ano de referência do Censo Escolar usado para as escolas.
ANO_ESCOLAS = 2025

HEADERS = {"User-Agent": "bdgeo-escolas-itabira/1.0 (trabalho academico CSI803)"}


def baixar(url: str, destino: Path, params: dict | None = None, timeout: int = 300) -> Path:
    """Baixa uma URL para um arquivo, falhando em qualquer status HTTP de erro."""
    destino.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, params=params, headers=HEADERS, timeout=timeout, stream=True) as r:
        r.raise_for_status()
        with open(destino, "wb") as f:
            for bloco in r.iter_content(chunk_size=1 << 16):
                f.write(bloco)
    return destino


def sha256(caminho: Path) -> str:
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def registrar_fonte(
    id_: str,
    arquivo: Path,
    *,
    camada: str,
    orgao: str,
    url: str,
    versao: str,
    licenca: str,
    observacao: str = "",
) -> None:
    """Grava (ou atualiza) a entrada de um arquivo bruto no manifesto de fontes."""
    BRUTOS.mkdir(parents=True, exist_ok=True)
    fontes = json.loads(MANIFESTO.read_text(encoding="utf-8")) if MANIFESTO.exists() else {}
    fontes[id_] = {
        "camada": camada,
        "arquivo": arquivo.relative_to(RAIZ).as_posix(),
        "orgao": orgao,
        "url": url,
        "data_coleta": date.today().isoformat(),
        "versao": versao,
        "licenca": licenca,
        "tamanho_bytes": arquivo.stat().st_size,
        "sha256": sha256(arquivo),
        "observacao": observacao,
    }
    MANIFESTO.write_text(json.dumps(fontes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"  registrado: {fontes[id_]['arquivo']} ({fontes[id_]['tamanho_bytes']:,} bytes)")
