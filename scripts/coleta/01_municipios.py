"""Coleta dos municípios do recorte (IBGE).

Baixa:
  1. a lista de municípios da microrregião (API de localidades);
  2. a malha municipal em GeoJSON (API de malhas v3, qualidade máxima);
  3. população residente e área territorial do Censo 2022 (SIDRA, tabela 4714).
"""
from comum import BRUTOS, COD_MICRORREGIAO, baixar, registrar_fonte

LICENCA_IBGE = "Dados abertos do IBGE; uso e redistribuição livres com citação da fonte (IBGE)."

URL_LOCALIDADES = (
    f"https://servicodados.ibge.gov.br/api/v1/localidades/microrregioes/{COD_MICRORREGIAO}/municipios"
)
URL_MALHA = f"https://servicodados.ibge.gov.br/api/v3/malhas/microrregioes/{COD_MICRORREGIAO}"
PARAMS_MALHA = {
    "formato": "application/vnd.geo+json",
    "qualidade": "maxima",
    "intrarregiao": "municipio",
}
# Tabela 4714: População residente, área territorial e densidade (Censo 2022).
# n9 = microrregião; v/93 = população residente, v/6318 = área territorial (km²).
URL_SIDRA = f"https://apisidra.ibge.gov.br/values/t/4714/n6/in%20n9%20{COD_MICRORREGIAO}/v/93,6318/p/2022"


def main() -> None:
    print("Municípios: lista da microrregião (API de localidades)")
    arq = baixar(URL_LOCALIDADES, BRUTOS / "ibge" / f"localidades_microrregiao_{COD_MICRORREGIAO}.json")
    registrar_fonte(
        "ibge_localidades",
        arq,
        camada="municipio",
        orgao="IBGE – API de Localidades",
        url=URL_LOCALIDADES,
        versao="API v1 (divisão territorial vigente na data de coleta)",
        licenca=LICENCA_IBGE,
    )

    print("Municípios: malha municipal (API de malhas v3)")
    arq = baixar(URL_MALHA, BRUTOS / "ibge" / f"malha_municipios_microrregiao_{COD_MICRORREGIAO}.geojson",
                 params=PARAMS_MALHA)
    registrar_fonte(
        "ibge_malha",
        arq,
        camada="municipio",
        orgao="IBGE – API de Malhas Geográficas",
        url=URL_MALHA + "?formato=application/vnd.geo+json&qualidade=maxima&intrarregiao=municipio",
        versao="API v3, malha vigente na data de coleta",
        licenca=LICENCA_IBGE,
        observacao=(
            "GeoJSON em coordenadas geográficas. O formato GeoJSON declara WGS 84 por especificação, "
            "mas a malha do IBGE é SIRGAS 2000 (EPSG:4674); o SRID é atribuído no tratamento."
        ),
    )

    print("Municípios: população e área do Censo 2022 (SIDRA 4714)")
    arq = baixar(URL_SIDRA, BRUTOS / "ibge" / f"sidra_4714_censo2022_microrregiao_{COD_MICRORREGIAO}.json")
    registrar_fonte(
        "ibge_sidra_4714",
        arq,
        camada="municipio",
        orgao="IBGE – SIDRA, tabela 4714 (Censo Demográfico 2022)",
        url=URL_SIDRA,
        versao="Censo Demográfico 2022",
        licenca=LICENCA_IBGE,
        observacao="Variáveis 93 (população residente) e 6318 (área territorial, km²).",
    )


if __name__ == "__main__":
    main()
