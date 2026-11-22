"""Coleta das escolas (INEP, distribuídas pelo pacote geobr do IPEA).

O geobr publica o cadastro de escolas do Censo Escolar (INEP) com coordenadas.
Baixamos o estado inteiro, sem filtro nem alteração, e salvamos em GeoPackage;
o recorte para a microrregião acontece na etapa de tratamento.
"""
from importlib.metadata import version

import geobr

from comum import ANO_ESCOLAS, BRUTOS, UF, registrar_fonte


def main() -> None:
    print(f"Escolas: geobr.read_schools(year={ANO_ESCOLAS}, code_muni='{UF}')")
    escolas = geobr.read_schools(year=ANO_ESCOLAS, code_muni=UF, show_progress=False)
    print(f"  {len(escolas):,} escolas em {UF}; CRS {escolas.crs}")

    destino = BRUTOS / "inep_geobr" / f"escolas_{UF.lower()}_{ANO_ESCOLAS}.gpkg"
    destino.parent.mkdir(parents=True, exist_ok=True)
    escolas.to_file(destino, layer="escolas", driver="GPKG")

    registrar_fonte(
        "inep_escolas_geobr",
        destino,
        camada="escola",
        orgao="INEP – Censo Escolar (cadastro de escolas), distribuído por IPEA/geobr",
        url="https://github.com/ipeaGIT/geobr (função read_schools)",
        versao=f"Censo Escolar {ANO_ESCOLAS}; geobr {version('geobr')}",
        licenca=(
            "Dados públicos do INEP, citar o INEP e o geobr (IPEA). O site do INEP adota "
            "CC BY-ND 3.0 para seu conteúdo; uso confirmado como fonte do Anexo A do enunciado."
        ),
        observacao=(
            "Estado inteiro, como entregue pelo geobr. Coordenadas lat_inep/lon_inep do INEP; "
            "colunas *_geocodebr trazem a geocodificação do IPEA como alternativa."
        ),
    )


if __name__ == "__main__":
    main()
