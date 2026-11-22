"""Etapa 3 - Tratamento: dados/brutos/ -> dados/tratados/*.csv (geometria em EWKT, SRID 4674).

O que faz:
  * municipio: une a malha do IBGE (geometria), a API de Localidades (nome, regiao imediata)
    e o SIDRA 4714 (populacao e area do Censo 2022); atribui SRID 4674 e converte para MultiPolygon.
  * escola: filtra as escolas do geobr pelos municipios do recorte, padroniza texto,
    confere codigos contra as tabelas de dominio e confere cada ponto com o municipio declarado
    (equivalente a ST_Within; so registra, nao move o ponto).
  * trecho_rodoviario: filtra a malha rodoviaria pelo recorte, corta cada trecho pelo limite
    dos municipios (overlay), calcula a extensao em km em UTM 23S e converte para MultiLineString.
  * dominios: dependencia administrativa, situacao de funcionamento, jurisdicao e superficie.
Todas as geometrias passam por make_valid e sao conferidas. Divergencias vao para scripts/log_tratamento.txt.

Uso (a partir da raiz do repositorio): python scripts/tratamento/tratar.py
"""
from __future__ import annotations

import json
import zipfile
from pathlib import Path

import geopandas as gpd
import pandas as pd
import shapely
from shapely import make_valid
from shapely.geometry import MultiLineString, MultiPolygon

RAIZ = Path(__file__).resolve().parents[2]
BRUTOS = RAIZ / "dados" / "brutos"
TRATADOS = RAIZ / "dados" / "tratados"
LOG = RAIZ / "scripts" / "log_tratamento.txt"
SRID = 4674
COD_MICRORREGIAO = 31031
UF = "MG"
ANO_ESCOLAS = 2025

linhas_log: list[str] = []


def log(msg: str = "") -> None:
    print(msg)
    linhas_log.append(msg)


# ---------------------------------------------------------------- dominios
DEPENDENCIA = {1: "Federal", 2: "Estadual", 3: "Municipal", 4: "Privada"}
SITUACAO = {1: "Em atividade", 2: "Paralisada", 3: "Extinta (ano do Censo)"}
JURISDICAO = {"F": "Federal", "E": "Estadual", "N": "Nao informada"}
SUPERFICIE = {
    "PAV": "Pavimentada",
    "DUP": "Pavimentada duplicada",
    "IMP": "Implantada (sem pavimento)",
    "LEN": "Leito natural",
    "PLA": "Planejada",
    "EOP": "Em obras de pavimentacao",
    "EOD": "Em obras de duplicacao",
    "N": "Nao informada",
}


def texto(s: pd.Series) -> pd.Series:
    """Remove espacos extras e vazios; nao altera acentos (UTF-8 preservado nos valores)."""
    s = s.astype("string").str.strip().str.replace(r"\s+", " ", regex=True)
    return s.mask(s == "", pd.NA)


def para_multi(g):
    if g.geom_type == "Polygon":
        return MultiPolygon([g])
    if g.geom_type == "LineString":
        return MultiLineString([g])
    return g


def validar(gdf: gpd.GeoDataFrame, nome: str) -> gpd.GeoDataFrame:
    invalidas = ~gdf.geometry.is_valid
    log(f"[{nome}] geometrias invalidas antes do make_valid: {int(invalidas.sum())}")
    gdf = gdf.copy()
    gdf.loc[invalidas, "geometry"] = gdf.loc[invalidas, "geometry"].apply(make_valid)
    gdf["geometry"] = gdf.geometry.apply(para_multi)
    ruins = (~gdf.geometry.is_valid) | gdf.geometry.is_empty | gdf.geometry.isna()
    if ruins.any():
        raise SystemExit(f"[{nome}] ainda ha {int(ruins.sum())} geometrias invalidas/vazias")
    return gdf


def ewkt(gdf: gpd.GeoDataFrame, colunas: list[str]) -> pd.DataFrame:
    df = pd.DataFrame(gdf[colunas])
    df["geom"] = [f"SRID={SRID};" + shapely.to_wkt(g, rounding_precision=9, trim=True) for g in gdf.geometry]
    return df


def salvar(df: pd.DataFrame, nome: str) -> None:
    TRATADOS.mkdir(parents=True, exist_ok=True)
    df.to_csv(TRATADOS / f"{nome}.csv", index=False, encoding="utf-8", lineterminator="\n")
    log(f"[{nome}] {len(df)} registros gravados em dados/tratados/{nome}.csv")


# ---------------------------------------------------------------- municipio
def tratar_municipios() -> gpd.GeoDataFrame:
    mun = gpd.read_file(BRUTOS / "ibge" / f"malha_municipios_microrregiao_{COD_MICRORREGIAO}.geojson")
    mun = mun.set_crs(SRID, allow_override=True)  # GeoJSON declara WGS 84; a malha IBGE e SIRGAS 2000
    mun["cod_ibge"] = mun["codarea"].astype(int)

    loc = json.loads((BRUTOS / "ibge" / f"localidades_microrregiao_{COD_MICRORREGIAO}.json").read_text(encoding="utf-8"))
    nomes = pd.DataFrame(
        {
            "cod_ibge": [m["id"] for m in loc],
            "nome": [m["nome"] for m in loc],
            "regiao_imediata": [m["regiao-imediata"]["nome"] for m in loc],
        }
    )

    sidra = json.loads((BRUTOS / "ibge" / f"sidra_4714_censo2022_microrregiao_{COD_MICRORREGIAO}.json").read_text(encoding="utf-8"))[1:]
    s = pd.DataFrame(sidra)[["D1C", "D2C", "V"]]
    s["cod_ibge"] = s["D1C"].astype(int)
    s["V"] = pd.to_numeric(s["V"], errors="coerce")
    pop = s[s["D2C"] == "93"].set_index("cod_ibge")["V"].rename("populacao")
    area = s[s["D2C"] == "6318"].set_index("cod_ibge")["V"].rename("area_km2")

    mun = mun.merge(nomes, on="cod_ibge", how="left", validate="one_to_one")
    mun = mun.merge(pop, on="cod_ibge", how="left").merge(area, on="cod_ibge", how="left")
    mun["uf"] = UF
    mun["nome"] = texto(mun["nome"])
    faltando = int(mun[["nome", "populacao", "area_km2"]].isna().any(axis=1).sum())
    log(f"[municipio] {len(mun)} municipios; com atributo ausente: {faltando}")
    if faltando:
        raise SystemExit("municipio com atributo ausente")
    mun["populacao"] = mun["populacao"].astype(int)
    mun["area_km2"] = mun["area_km2"].round(3)

    mun = validar(mun, "municipio")
    # confere area oficial x area calculada da malha (so informativo)
    calc = mun.to_crs(31983).area / 1e6
    dif = ((calc - mun["area_km2"]) / mun["area_km2"] * 100).abs()
    log(f"[municipio] maior diferenca entre area oficial e area da malha: {dif.max():.2f}%")
    cols = ["cod_ibge", "nome", "uf", "regiao_imediata", "area_km2", "populacao"]
    salvar(ewkt(mun.sort_values("cod_ibge"), cols), "municipio")
    return mun


# ---------------------------------------------------------------- escola
def tratar_escolas(mun: gpd.GeoDataFrame) -> pd.DataFrame:
    esc = gpd.read_file(BRUTOS / "inep_geobr" / f"escolas_{UF.lower()}_{ANO_ESCOLAS}.gpkg")
    log(f"[escola] lidas {len(esc)} escolas de {UF}")
    esc = esc[esc["code_muni"].isin(mun["cod_ibge"])].copy()
    log(f"[escola] dentro dos {len(mun)} municipios do recorte: {len(esc)}")

    antes = len(esc)
    esc = esc[esc.geometry.notna() & ~esc.geometry.is_empty]
    log(f"[escola] removidas por coordenada nula/vazia: {antes - len(esc)}")
    if esc.crs.to_epsg() != SRID:
        esc = esc.to_crs(SRID)

    esc["cod_inep"] = esc["code_school"].astype("int64")
    log(f"[escola] cod_inep duplicado: {int(esc['cod_inep'].duplicated().sum())}")
    esc = esc.drop_duplicates("cod_inep")
    esc["cod_ibge"] = esc["code_muni"].astype(int)
    esc["nome"] = texto(esc["name_school"])
    esc["cod_dependencia"] = esc["tp_dependencia"].astype("Int64")
    esc["cod_situacao"] = esc["tp_situacao_funcionamento"].astype("Int64")
    esc["localizacao"] = esc["tp_localizacao"].map({1: "urbana", 2: "rural"})
    esc["endereco"] = texto(esc["ds_endereco"])
    esc["bairro"] = texto(esc["no_bairro"])
    esc["cep"] = texto(esc["co_cep"].astype("Int64").astype("string").str.zfill(8))

    for col in ["nome", "cod_dependencia", "cod_situacao", "localizacao"]:
        n = int(esc[col].isna().sum())
        if n:
            log(f"[escola] ATENCAO: {n} nulos em {col}")
    for nome_col, dom in [("cod_dependencia", DEPENDENCIA), ("cod_situacao", SITUACAO)]:
        if not esc[nome_col].isin(dom.keys()).all():
            raise SystemExit(f"codigo fora do dominio em {nome_col}")
    log(
        f"[escola] enderecos nulos: {int(esc['endereco'].isna().sum())}; "
        f"bairros nulos: {int(esc['bairro'].isna().sum())}; cep nulo: {int(esc['cep'].isna().sum())}"
    )

    esc = validar(esc, "escola")

    # Equivalente a ST_Within(escola, municipio): o ponto cai no municipio declarado? (so registra)
    mun_idx = mun.set_index("cod_ibge").geometry
    dentro = [mun_idx.loc[c].contains(p) for c, p in zip(esc["cod_ibge"], esc.geometry)]
    fora = esc.loc[[not d for d in dentro]]
    log(f"[escola] pontos fora do municipio declarado: {len(fora)} de {len(esc)}")
    for _, r in fora.iterrows():
        log(f"    cod_inep={r.cod_inep} municipio={r.cod_ibge} nome={r.nome} (mantida, coordenada do INEP)")

    cols = ["cod_inep", "nome", "cod_ibge", "cod_dependencia", "cod_situacao", "localizacao", "endereco", "bairro", "cep"]
    out = ewkt(esc.sort_values("cod_inep"), cols)
    salvar(out, "escola")
    return out


# ---------------------------------------------------------------- trecho_rodoviario
def tratar_rodovias(mun: gpd.GeoDataFrame) -> pd.DataFrame:
    zip_path = BRUTOS / "ide_sisema" / "ide_0401_mg_rodovias_lin.zip"
    with zipfile.ZipFile(zip_path) as z:
        shp = next(n for n in z.namelist() if n.lower().endswith(".shp"))
    rod = gpd.read_file(f"zip://{zip_path.as_posix()}!{shp}")
    if rod.crs is None or rod.crs.to_epsg() != SRID:
        rod = rod.to_crs(SRID) if rod.crs else rod.set_crs(SRID)
    log(f"[trecho_rodoviario] lidos {len(rod)} trechos de {UF}")

    rod = rod[rod.intersects(mun.union_all())].copy()
    log(f"[trecho_rodoviario] trechos que cruzam o recorte: {len(rod)}")

    pedacos = gpd.overlay(rod, mun[["cod_ibge", "geometry"]], how="intersection", keep_geom_type=True)
    log(f"[trecho_rodoviario] pedacos apos cortar por municipio: {len(pedacos)}")

    pedacos["extensao_km"] = (pedacos.to_crs(31983).length / 1000).round(3)
    miudos = pedacos["extensao_km"] < 0.001
    log(f"[trecho_rodoviario] pedacos com menos de 1 m descartados: {int(miudos.sum())}")
    pedacos = pedacos[~miudos].copy()

    # Codigo da rodovia: prefixo pela jurisdicao (BR- federal, MG- estadual) + codigo_rod
    pedacos["cod_jurisdicao"] = pedacos["jurisdicao"].map({"Federal": "F", "Estadual": "E"}).fillna("N")
    pref = pedacos["cod_jurisdicao"].map({"F": "BR-", "E": "MG-", "N": ""})
    pedacos["codigo"] = (pref + texto(pedacos["codigo_rod"]).fillna("")).replace("", pd.NA)
    pedacos["codigo_snv"] = texto(pedacos["codigo_snv"])
    pedacos["local_inicial"] = texto(pedacos["local_inic"])
    pedacos["local_final"] = texto(pedacos["local_fim"])
    pedacos["tipo_trecho"] = texto(pedacos["tipo_trech"])
    pedacos["cod_superficie"] = texto(pedacos["superficie"]).fillna("N")
    desconhecidas = set(pedacos["cod_superficie"]) - set(SUPERFICIE)
    if desconhecidas:
        raise SystemExit(f"superficie fora do dominio: {desconhecidas}")
    log(
        f"[trecho_rodoviario] jurisdicao nao informada: {int((pedacos.cod_jurisdicao == 'N').sum())}; "
        f"superficie nao informada: {int((pedacos.cod_superficie == 'N').sum())}"
    )
    log(f"[trecho_rodoviario] codigo nulo: {int(pedacos['codigo'].isna().sum())}; tipo_trecho nulo: {int(pedacos['tipo_trecho'].isna().sum())}")

    pedacos = validar(pedacos, "trecho_rodoviario")
    pedacos = pedacos.sort_values(["cod_ibge", "codigo", "codigo_snv"]).reset_index(drop=True)
    pedacos["id_trecho"] = pedacos.index + 1
    cols = ["id_trecho", "cod_ibge", "codigo", "codigo_snv", "tipo_trecho", "local_inicial", "local_final",
            "cod_jurisdicao", "cod_superficie", "extensao_km"]
    out = ewkt(pedacos, cols)
    salvar(out, "trecho_rodoviario")
    return out


def tratar_dominios() -> None:
    salvar(pd.DataFrame({"cod_dependencia": list(DEPENDENCIA), "descricao": list(DEPENDENCIA.values())}), "dominio_dependencia")
    salvar(pd.DataFrame({"cod_situacao": list(SITUACAO), "descricao": list(SITUACAO.values())}), "dominio_situacao")
    salvar(pd.DataFrame({"cod_jurisdicao": list(JURISDICAO), "descricao": list(JURISDICAO.values())}), "dominio_jurisdicao")
    salvar(pd.DataFrame({"cod_superficie": list(SUPERFICIE), "descricao": list(SUPERFICIE.values())}), "dominio_superficie")


def main() -> None:
    log("Log do tratamento (scripts/tratamento/tratar.py)")
    log(f"geopandas {gpd.__version__}, shapely {shapely.__version__}")
    log()
    tratar_dominios()
    mun = tratar_municipios()
    tratar_escolas(mun)
    tratar_rodovias(mun)
    LOG.write_text("\n".join(linhas_log) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
