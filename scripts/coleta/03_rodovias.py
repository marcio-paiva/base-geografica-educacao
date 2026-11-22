"""Coleta das rodovias estaduais e federais de MG (IDE-Sisema / DNIT).

Baixa a camada inteira (cerca de 3.400 trechos no estado) como shapefile
compactado, pelo serviço WFS do GeoServer da Semad. O recorte para a
microrregião acontece na etapa de tratamento.
"""
from comum import BRUTOS, baixar, registrar_fonte

URL_WFS = "https://geoserver.meioambiente.mg.gov.br/IDE/ows"
PARAMS = {
    "service": "WFS",
    "version": "1.0.0",
    "request": "GetFeature",
    "typeName": "IDE:ide_0401_mg_rodovias_lin",
    "maxFeatures": "10000000",
    "outputFormat": "SHAPE-ZIP",
}
URL_METADADO = (
    "https://idesisema.meioambiente.mg.gov.br/geonetwork/srv/api/records/"
    "ba9062d9-15d1-4373-9638-2ef8ce885f74"
)


def main() -> None:
    print("Rodovias: WFS IDE-Sisema (ide_0401_mg_rodovias_lin)")
    destino = BRUTOS / "ide_sisema" / "ide_0401_mg_rodovias_lin.zip"
    baixar(URL_WFS, destino, params=PARAMS, timeout=600)

    # O GeoServer devolve XML de erro com status 200 em algumas falhas: confere a assinatura ZIP.
    with open(destino, "rb") as f:
        if f.read(2) != b"PK":
            raise RuntimeError(f"Resposta do WFS não é um ZIP: veja {destino}")

    query = "&".join(f"{k}={v}" for k, v in PARAMS.items())
    registrar_fonte(
        "ide_sisema_rodovias",
        destino,
        camada="trecho_rodoviario",
        orgao="DNIT (SNV) e Semad/MG, distribuído pela IDE-Sisema",
        url=f"{URL_WFS}?{query}",
        versao="Rodovias estaduais e federais de MG; dados atualizados em 12/2021 (metadado revisado em 2022-06-29)",
        licenca="Metadado declara 'O acesso ao dado é livre'; citar DNIT e IDE-Sisema. Metadado: " + URL_METADADO,
        observacao="Shapefile compactado do estado inteiro, EPSG:4674.",
    )


if __name__ == "__main__":
    main()
