"""Contagem preliminar de feições dentro do recorte e geração de FONTES.md.

Não altera os dados brutos: só lê, filtra em memória e conta, para confirmar
que o recorte atende ao mínimo de 500 feições do enunciado.
Saídas: dados/brutos/contagem_preliminar.json e dados/brutos/FONTES.md.
"""
import json
import zipfile

import geopandas as gpd
import pandas as pd

from comum import ANO_ESCOLAS, BRUTOS, COD_MICRORREGIAO, MANIFESTO, NOME_RECORTE, UF

MINIMO = 500


def carregar_municipios() -> gpd.GeoDataFrame:
    mun = gpd.read_file(BRUTOS / "ibge" / f"malha_municipios_microrregiao_{COD_MICRORREGIAO}.geojson")
    # GeoJSON declara WGS 84; a malha do IBGE é SIRGAS 2000.
    return mun.set_crs(4674, allow_override=True).rename(columns={"codarea": "cod_ibge"})


def contar_escolas(cods: set[int]) -> dict:
    esc = gpd.read_file(BRUTOS / "inep_geobr" / f"escolas_{UF.lower()}_{ANO_ESCOLAS}.gpkg")
    esc = esc[esc["code_muni"].isin(cods)]
    sit = esc["tp_situacao_funcionamento"].map({1: "em_atividade", 2: "paralisada", 3: "extinta"})
    return {
        "total": int(len(esc)),
        "por_situacao": {str(k): int(v) for k, v in sit.fillna("sem_info").value_counts().items()},
        "sem_coordenada": int(esc.geometry.is_empty.sum() + esc.geometry.isna().sum()),
    }


def contar_rodovias(mun: gpd.GeoDataFrame) -> dict:
    zip_path = BRUTOS / "ide_sisema" / "ide_0401_mg_rodovias_lin.zip"
    with zipfile.ZipFile(zip_path) as z:
        shp = next(n for n in z.namelist() if n.lower().endswith(".shp"))
    rod = gpd.read_file(f"zip://{zip_path.as_posix()}!{shp}")
    if rod.crs is None or rod.crs.to_epsg() != 4674:
        rod = rod.to_crs(4674) if rod.crs else rod.set_crs(4674)
    recorte = mun.union_all()
    rod_rec = rod[rod.intersects(recorte)]
    # Cada trecho cortado por município vira uma feição da tabela final.
    pedacos = gpd.overlay(rod_rec, mun[["cod_ibge", "geometry"]], how="intersection", keep_geom_type=True)
    return {
        "trechos_estado": int(len(rod)),
        "trechos_no_recorte": int(len(rod_rec)),
        "trechos_por_municipio": int(len(pedacos)),
        "colunas": [c for c in rod.columns if c != "geometry"],
    }


def gerar_fontes_md() -> None:
    fontes = json.loads(MANIFESTO.read_text(encoding="utf-8"))
    linhas = [
        "# Fontes dos dados brutos",
        "",
        "Gerado por `scripts/coleta/04_contagem.py` a partir de `fontes.json`. "
        "Os arquivos desta pasta estão exatamente como foram baixados.",
        "",
    ]
    for f in fontes.values():
        linhas += [
            f"## {f['arquivo']}",
            "",
            f"- **Camada:** `{f['camada']}`",
            f"- **Órgão:** {f['orgao']}",
            f"- **URL:** {f['url']}",
            f"- **Data de coleta:** {f['data_coleta']}",
            f"- **Versão:** {f['versao']}",
            f"- **Licença:** {f['licenca']}",
            f"- **Tamanho:** {f['tamanho_bytes']:,} bytes".replace(",", "."),
            f"- **SHA-256:** `{f['sha256']}`",
        ]
        if f.get("observacao"):
            linhas.append(f"- **Observação:** {f['observacao']}")
        linhas.append("")
    (BRUTOS / "FONTES.md").write_text("\n".join(linhas), encoding="utf-8")


def main() -> None:
    mun = carregar_municipios()
    cods = set(pd.to_numeric(mun["cod_ibge"]).astype(int))
    esc = contar_escolas(cods)
    rod = contar_rodovias(mun)

    total = len(mun) + esc["total"] + rod["trechos_por_municipio"]
    resultado = {
        "recorte": NOME_RECORTE,
        "municipios": int(len(mun)),
        "escolas": esc,
        "rodovias": rod,
        "total_feicoes_estimado": int(total),
        "minimo_enunciado": MINIMO,
        "atende_minimo": total >= MINIMO,
    }
    (BRUTOS / "contagem_preliminar.json").write_text(
        json.dumps(resultado, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    gerar_fontes_md()
    print(json.dumps(resultado, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
