# Fontes dos dados brutos

Gerado por `scripts/coleta/04_contagem.py` a partir de `fontes.json`. Os arquivos desta pasta estão exatamente como foram baixados.

## dados/brutos/ibge/localidades_microrregiao_31031.json

- **Camada:** `municipio`
- **Órgão:** IBGE – API de Localidades
- **URL:** https://servicodados.ibge.gov.br/api/v1/localidades/microrregioes/31031/municipios
- **Data de coleta:** 2026-11-22
- **Versão:** API v1 (divisão territorial vigente na data de coleta)
- **Licença:** Dados abertos do IBGE; uso e redistribuição livres com citação da fonte (IBGE).
- **Tamanho:** 8.289 bytes
- **SHA-256:** `422247023d910e1137245b771dc374c95bf0db2d6909883dfd35d158b33b7da4`

## dados/brutos/ibge/malha_municipios_microrregiao_31031.geojson

- **Camada:** `municipio`
- **Órgão:** IBGE – API de Malhas Geográficas
- **URL:** https://servicodados.ibge.gov.br/api/v3/malhas/microrregioes/31031?formato=application/vnd.geo+json&qualidade=maxima&intrarregiao=municipio
- **Data de coleta:** 2026-11-22
- **Versão:** API v3, malha vigente na data de coleta
- **Licença:** Dados abertos do IBGE; uso e redistribuição livres com citação da fonte (IBGE).
- **Tamanho:** 165.573 bytes
- **SHA-256:** `2a7fa856a5a00baa1edf5ed18934d1d16706cc9422fafeb3ef50b86a3f95bf16`
- **Observação:** GeoJSON em coordenadas geográficas. O formato GeoJSON declara WGS 84 por especificação, mas a malha do IBGE é SIRGAS 2000 (EPSG:4674); o SRID é atribuído no tratamento.

## dados/brutos/ibge/sidra_4714_censo2022_microrregiao_31031.json

- **Camada:** `municipio`
- **Órgão:** IBGE – SIDRA, tabela 4714 (Censo Demográfico 2022)
- **URL:** https://apisidra.ibge.gov.br/values/t/4714/n6/in%20n9%2031031/v/93,6318/p/2022
- **Data de coleta:** 2026-11-22
- **Versão:** Censo Demográfico 2022
- **Licença:** Dados abertos do IBGE; uso e redistribuição livres com citação da fonte (IBGE).
- **Tamanho:** 10.287 bytes
- **SHA-256:** `dc2cc8af59bdfbad2744f575003eb1d196f8e8548c530e5cd7b5b4451032b1c1`
- **Observação:** Variáveis 93 (população residente) e 6318 (área territorial, km²).

## dados/brutos/inep_geobr/escolas_mg_2025.gpkg

- **Camada:** `escola`
- **Órgão:** INEP – Censo Escolar (cadastro de escolas), distribuído por IPEA/geobr
- **URL:** https://github.com/ipeaGIT/geobr (função read_schools)
- **Data de coleta:** 2026-11-22
- **Versão:** Censo Escolar 2025; geobr 2.1.1
- **Licença:** Dados públicos do INEP, citar o INEP e o geobr (IPEA). O site do INEP adota CC BY-ND 3.0 para seu conteúdo; uso confirmado como fonte do Anexo A do enunciado.
- **Tamanho:** 6.946.816 bytes
- **SHA-256:** `fb0cfdcbebd57cea93beeebad72567912d91b691ccef154ca77eb6b1689e7b04`
- **Observação:** Estado inteiro, como entregue pelo geobr. Coordenadas lat_inep/lon_inep do INEP; colunas *_geocodebr trazem a geocodificação do IPEA como alternativa.

## dados/brutos/ide_sisema/ide_0401_mg_rodovias_lin.zip

- **Camada:** `trecho_rodoviario`
- **Órgão:** DNIT (SNV) e Semad/MG, distribuído pela IDE-Sisema
- **URL:** https://geoserver.meioambiente.mg.gov.br/IDE/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=IDE:ide_0401_mg_rodovias_lin&maxFeatures=10000000&outputFormat=SHAPE-ZIP
- **Data de coleta:** 2026-11-22
- **Versão:** Rodovias estaduais e federais de MG; dados atualizados em 12/2021 (metadado revisado em 2022-06-29)
- **Licença:** Metadado declara 'O acesso ao dado é livre'; citar DNIT e IDE-Sisema. Metadado: https://idesisema.meioambiente.mg.gov.br/geonetwork/srv/api/records/ba9062d9-15d1-4373-9638-2ef8ce885f74
- **Tamanho:** 31.011.361 bytes
- **SHA-256:** `9241bccbedf662e54d3b5b0c61d7d59be5aaa416465e75ed7eed9a43f3e48d1e`
- **Observação:** Shapefile compactado do estado inteiro, EPSG:4674.
