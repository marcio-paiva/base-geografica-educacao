# Dicionário de dados – Base geográfica de escolas da Microrregião de Itabira (MG)

## 1. Visão geral da base

| Item | Descrição |
| --- | --- |
| **Título** | Base geográfica de escolas da Microrregião de Itabira (MG) (`bdgeo_escolas`) |
| **Descrição e finalidade** | Base com os 18 municípios da Microrregião de Itabira, as escolas do Censo Escolar 2025 localizadas nesses municípios e os trechos de rodovias federais e estaduais que os atravessam. Finalidade: apoiar análises de distribuição espacial da rede de ensino e de acessibilidade das escolas, sobretudo das rurais, à malha rodoviária. |
| **Fontes** | **Municípios:** IBGE, API de Localidades (lista e região imediata), API de Malhas Geográficas v3 (limites) e SIDRA, tabela 4714, Censo Demográfico 2022 (população e área). **Escolas:** INEP, Censo Escolar 2025 (cadastro de escolas com coordenadas), distribuído pelo pacote geobr 2.1.1 (IPEA). **Rodovias:** DNIT, Sistema Nacional de Viação (SNV), camada "Rodovias estaduais e federais de MG" (`ide_0401_mg_rodovias_lin`) distribuída pela IDE-Sisema (Semad/MG). URLs completas de cada arquivo em [`dados/brutos/FONTES.md`](dados/brutos/FONTES.md). |
| **Data de coleta** | 22/11/2026 (todas as fontes). |
| **Versão das fontes** | Divisão territorial e malha municipal vigentes em 22/11/2026; Censo Demográfico 2022; Censo Escolar 2025 (geobr 2.1.1); rodovias atualizadas em 12/2021 (metadado revisado em 29/06/2022). |
| **Licença** | IBGE: dados abertos, uso e redistribuição livres com citação da fonte. INEP: dados públicos do Censo Escolar, com citação do INEP e do geobr (IPEA); o portal do INEP adota CC BY-ND 3.0 para seu conteúdo, e a fonte consta no Anexo A do enunciado. DNIT/IDE-Sisema: o metadado declara "O acesso ao dado é livre", com citação do DNIT e da IDE-Sisema. Nenhum dado pessoal é incluído. Licença do repositório: ver [LICENSE](LICENSE). |
| **Cobertura espacial** | Microrregião de Itabira (código IBGE 31031), Minas Gerais: 18 municípios, que pertencem a 6 regiões geográficas imediatas (divisão do IBGE de 2017). Caixa envolvente aproximada: longitude de 43,79° O a 42,47° O e latitude de 20,22° S a 19,06° S. |
| **Cobertura temporal** | Retrato estático, sem série histórica: população de 2022, escolas do Censo Escolar 2025 e rodovias de 12/2021. |
| **SRID e justificativa** | **EPSG:4674 (SIRGAS 2000, coordenadas geográficas)** em todas as tabelas. É o datum oficial do Brasil e o sistema nativo da malha do IBGE e da camada de rodovias da IDE-Sisema, o que evita reprojetar os limites e os trechos. Medidas em metros (extensão dos trechos, distâncias) são feitas convertendo para `geography` ou reprojetando para **EPSG:31983 (SIRGAS 2000 / UTM 23S)**, a zona UTM que cobre toda a microrregião. |
| **Escala e precisão** | Municípios: malha municipal do IBGE na qualidade máxima da API v3. A diferença entre a área oficial do Censo 2022 e a área calculada da malha em UTM 23S é de no máximo 0,08%. Escolas: coordenadas (latitude e longitude) declaradas no cadastro do INEP, com precisão variável. Rodovias: geometria do SNV/DNIT, sem escala declarada no metadado. Coordenadas gravadas com até 9 casas decimais. |
| **Volume** | 790 feições: 18 municípios, 624 escolas e 148 trechos rodoviários. Há ainda 18 registros nas 4 tabelas de domínio. |

### 1.1 Tratamentos aplicados

Todos os tratamentos estão em [`scripts/tratamento/tratar.py`](scripts/tratamento/tratar.py) (Python 3.11, geopandas 1.2.0, shapely 2.2.0). As contagens de cada etapa ficam registradas em [`scripts/log_tratamento.txt`](scripts/log_tratamento.txt).

**Escolha do recorte.** O plano inicial previa a Região Geográfica Imediata de João Monlevade. Essa região tem apenas 6 municípios e não chegava às 500 feições exigidas. Por isso o recorte foi ampliado para a Microrregião de Itabira (IBGE 31031), que contém os 6 municípios da Região Imediata de João Monlevade e mais 12 municípios vizinhos.

**Municípios**
1. Seleção dos municípios da microrregião 31031 pela API de Localidades do IBGE.
2. Atribuição do SRID 4674. O GeoJSON declara WGS 84 por especificação do formato, mas a malha do IBGE é SIRGAS 2000.
3. Junção da malha com a lista de municípios (nome e região imediata) e com o SIDRA 4714 (população e área). Nenhum município ficou com atributo ausente.
4. Conversão para MultiPolygon e validação das geometrias com `make_valid` (0 geometrias inválidas encontradas).
5. Área arredondada para 3 casas decimais. A área oficial foi conferida contra a área calculada em UTM 23S (diferença máxima de 0,08%).

**Escolas**
1. Leitura das 24.069 escolas de MG do Censo Escolar 2025 e filtro pelo código IBGE dos 18 municípios do recorte: restaram 624.
2. Verificação de coordenadas nulas ou vazias (0 removidas) e de `cod_inep` duplicado (0).
3. **Manutenção das escolas paralisadas e extintas**, identificadas pela coluna `cod_situacao`. Das 624 escolas, 319 estão em atividade, 303 paralisadas e 2 extintas. Sem as paralisadas, a base não chegaria a 500 feições. Para analisar só as escolas em funcionamento, filtre com `cod_situacao = 1`.
4. Conversão da localização (1/2 do INEP) para `urbana`/`rural` e do CEP para texto com 8 dígitos (zeros à esquerda preservados).
5. Validação das geometrias (0 inválidas).
6. Conferência equivalente a `ST_Within(escola.geom, municipio.geom)`: as 624 escolas caem dentro do município declarado no cadastro. As coordenadas do INEP foram mantidas sem alteração.
7. O atributo "porte da escola", previsto no plano, não existe na fonte e não foi incluído.

**Trechos rodoviários**
1. Leitura dos 3.444 trechos de MG e seleção dos 113 que cruzam o recorte.
2. Corte dos trechos pelo limite de cada município (`overlay` de interseção), gerando 148 pedaços. Cada registro da tabela é um pedaço de trecho dentro de um único município.
3. Cálculo de `extensao_km` em UTM 23S (EPSG:31983), arredondado para 3 casas. Pedaços com menos de 1 m seriam descartados, mas nenhum foi encontrado.
4. Montagem do código da rodovia: prefixo pela jurisdição (`BR-` federal, `MG-` estadual) seguido do `codigo_rod` do SNV.
5. 16 pedaços não têm jurisdição, superfície, código nem demais atributos na fonte. Eles ficam com `N` (não informada) em `cod_jurisdicao` e `cod_superficie` e com nulo nas demais colunas textuais.
6. Conversão para MultiLineString e validação das geometrias (0 inválidas).

**Todas as tabelas**
- Nomes de tabelas e colunas em minúsculas, sem acentos e sem espaços (snake_case).
- Texto em UTF-8, sem espaços nas pontas e com espaços internos repetidos reduzidos a um. Os valores textuais mantêm a grafia da fonte, com acentos (por exemplo, `Alvinópolis`) e, no caso das escolas, em maiúsculas.
- Geometrias exportadas em EWKT (`SRID=4674;...`) nos CSV de `dados/tratados/`, carregados com `\copy` por [`sql/carga.sql`](sql/carga.sql).
- No banco, toda coluna `geom` é `NOT NULL` e tem `CHECK (ST_IsValid(geom) AND NOT ST_IsEmpty(geom))`, além de índice espacial GiST.

## 2. Relacionamentos

**Por chave (PK/FK)**

| Tabela de origem | Coluna | Referencia | Cardinalidade |
| --- | --- | --- | --- |
| `escola` | `cod_ibge` | `municipio.cod_ibge` | N escolas : 1 município |
| `escola` | `cod_dependencia` | `dominio_dependencia.cod_dependencia` | N : 1 |
| `escola` | `cod_situacao` | `dominio_situacao.cod_situacao` | N : 1 |
| `trecho_rodoviario` | `cod_ibge` | `municipio.cod_ibge` | N pedaços : 1 município |
| `trecho_rodoviario` | `cod_jurisdicao` | `dominio_jurisdicao.cod_jurisdicao` | N : 1 |
| `trecho_rodoviario` | `cod_superficie` | `dominio_superficie.cod_superficie` | N : 1 |

**Relações espaciais documentadas**

| Relação | Significado |
| --- | --- |
| `ST_Within(escola.geom, municipio.geom)` | Toda escola está dentro do município indicado por `escola.cod_ibge` (conferido para as 624). |
| `ST_Within(trecho_rodoviario.geom, municipio.geom)` | Cada pedaço de trecho está contido no município indicado por `trecho_rodoviario.cod_ibge`, porque foi gerado pelo corte no limite municipal. |
| `ST_DWithin(escola.geom::geography, trecho_rodoviario.geom::geography, d)` | Relação de proximidade (distância `d` em metros) usada para medir o acesso das escolas à rodovia mais próxima. |

## 3. Descrição das tabelas

### Tabela `municipio`

Limites dos municípios da Microrregião de Itabira, com população e área do Censo 2022. Geometria: **MultiPolygon** · SRID: **4674** · Registros: **18**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `cod_ibge` | integer | 7 dígitos (1000000 a 5999999) | Não | PK | Código do município no IBGE. | 3136207 |
| `nome` | varchar | 60 · único junto com `uf` | Não | | Nome oficial do município, com acentos. | João Monlevade |
| `uf` | char | 2 · sigla de UF (`^[A-Z]{2}$`) | Não | | Sigla da unidade da federação. Nesta base, sempre `MG`. | MG |
| `regiao_imediata` | varchar | 60 · 6 valores na base | Não | | Nome da Região Geográfica Imediata (IBGE, 2017) a que o município pertence. | João Monlevade |
| `area_km2` | numeric | (10,3) · > 0 | Não | | Área territorial oficial em km² (SIDRA 4714, variável 6318). Na base: de 99,158 a 1.253,704. | 99.158 |
| `populacao` | integer | ≥ 0 | Não | | População residente no Censo Demográfico 2022 (SIDRA 4714, variável 93). Na base: de 4.224 a 113.343. | 80187 |
| `geom` | geometry | MultiPolygon, 4674 | Não | | Limite municipal. Válida e não vazia (CHECK). Índice GiST `idx_municipio_geom`. | (geometria) |

Valores de `regiao_imediata` na base: João Monlevade (6 municípios), Itabira (4), Santa Bárbara - Ouro Preto (3), Ipatinga (2), Belo Horizonte (2) e Ponte Nova (1).

### Tabela `escola`

Escolas do Censo Escolar 2025 (INEP) localizadas nos municípios do recorte, com a coordenada do cadastro do INEP. Geometria: **Point** · SRID: **4674** · Registros: **624**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `cod_inep` | bigint | 8 dígitos (10000000 a 99999999) | Não | PK | Código da escola no INEP. | 31007676 |
| `nome` | varchar | 150 | Não | | Nome da escola, como no cadastro do INEP (maiúsculas). | ESCOLA MUNICIPAL PROFESSORA ROSINA RODRIGUES SOARES SILVA |
| `cod_ibge` | integer | 7 dígitos · ver `municipio` | Não | FK | Município da escola. Referencia `municipio.cod_ibge`. | 3105400 |
| `cod_dependencia` | smallint | 1 a 4 · ver `dominio_dependencia` | Não | FK | Dependência administrativa. Referencia `dominio_dependencia.cod_dependencia`. | 3 |
| `cod_situacao` | smallint | 1 a 3 · ver `dominio_situacao` | Não | FK | Situação de funcionamento no Censo Escolar 2025. Referencia `dominio_situacao.cod_situacao`. | 1 |
| `localizacao` | varchar | 7 · `urbana`, `rural` | Não | | Zona de localização da escola segundo o INEP. Na base: 450 urbanas e 174 rurais. | urbana |
| `endereco` | varchar | 200 | Não | | Logradouro (e número, quando informado) do cadastro do INEP. | RUA JOAO RAIMUNDO DA SILVEIRA |
| `bairro` | varchar | 100 | Sim | | Bairro do cadastro do INEP. Nulo em 270 escolas, em geral rurais. | CAPIM CHEIROSO |
| `cep` | char | 8 dígitos (`^[0-9]{8}$`) | Sim | | CEP da escola, só com dígitos e zeros à esquerda preservados. Preenchido nas 624 escolas da base. | 35970000 |
| `geom` | geometry | Point, 4674 | Não | | Localização da escola (latitude e longitude do INEP). Válida e não vazia (CHECK). Índice GiST `idx_escola_geom`. | (geometria) |

Índices adicionais: `idx_escola_cod_ibge` e `idx_escola_dependencia` (B-tree).

### Tabela `trecho_rodoviario`

Pedaços dos trechos de rodovias federais e estaduais do SNV/DNIT, cortados pelo limite de cada município do recorte. Um trecho do SNV que atravessa dois municípios aparece como dois registros. Geometria: **MultiLineString** · SRID: **4674** · Registros: **148**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `id_trecho` | integer | 1 a 148, gerado no tratamento | Não | PK | Identificador interno do pedaço, numerado em ordem de `cod_ibge`, `codigo` e `codigo_snv`. | 8 |
| `cod_ibge` | integer | 7 dígitos · ver `municipio` | Não | FK | Município que contém o pedaço. Referencia `municipio.cod_ibge`. | 3105400 |
| `codigo` | varchar | 10 · `BR-nnn` ou `MG-nnn` | Sim | | Código da rodovia: prefixo da jurisdição mais o `codigo_rod` do SNV. Nulo nos 16 pedaços sem atributos na fonte. | BR-381 |
| `codigo_snv` | varchar | 15 | Sim | | Código do trecho no Sistema Nacional de Viação. | 381BMG0310 |
| `tipo_trecho` | varchar | 20 · na base, só `Eixo Principal` | Sim | | Tipo do trecho segundo o SNV. | Eixo Principal |
| `local_inicial` | varchar | 100 | Sim | | Descrição do ponto inicial do trecho no SNV (o trecho inteiro, não o pedaço). | ENTR MG129 (SÃO GONÇALO DO RIO ABAIXO) |
| `local_final` | varchar | 100 | Sim | | Descrição do ponto final do trecho no SNV (o trecho inteiro, não o pedaço). | ENTR MG436 |
| `cod_jurisdicao` | char | 1 · ver `dominio_jurisdicao` | Não | FK | Jurisdição da rodovia. Referencia `dominio_jurisdicao.cod_jurisdicao`. Na base: 105 estaduais, 27 federais e 16 não informadas. | F |
| `cod_superficie` | varchar | 3 · ver `dominio_superficie` | Não | FK | Tipo de superfície do trecho. Referencia `dominio_superficie.cod_superficie`. | PAV |
| `extensao_km` | numeric | (8,3) · > 0 | Não | | Comprimento do pedaço dentro do município, em km, calculado em UTM 23S (EPSG:31983). Na base: de 0,046 a 28,921. | 5.148 |
| `geom` | geometry | MultiLineString, 4674 | Não | | Geometria do pedaço de trecho. Válida e não vazia (CHECK). Índice GiST `idx_trecho_geom`. | (geometria) |

Índice adicional: `idx_trecho_cod_ibge` (B-tree).

### Tabela `dominio_dependencia` (tabela de domínio)

Dependência administrativa da escola, com os códigos do Censo Escolar/INEP. Sem geometria · Registros: **4**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `cod_dependencia` | smallint | 1 a 4 | Não | PK | Código da dependência administrativa (INEP). | 3 |
| `descricao` | varchar | 30 · único | Não | | Descrição da dependência. | Municipal |

| `cod_dependencia` | `descricao` | Escolas na base |
| --- | --- | --- |
| 1 | Federal | 0 |
| 2 | Estadual | 101 |
| 3 | Municipal | 320 |
| 4 | Privada | 203 |

### Tabela `dominio_situacao` (tabela de domínio)

Situação de funcionamento da escola no Censo Escolar. Sem geometria · Registros: **3**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `cod_situacao` | smallint | 1 a 3 | Não | PK | Código da situação de funcionamento (INEP). | 1 |
| `descricao` | varchar | 40 · único | Não | | Descrição da situação. | Em atividade |

| `cod_situacao` | `descricao` | Escolas na base |
| --- | --- | --- |
| 1 | Em atividade | 319 |
| 2 | Paralisada | 303 |
| 3 | Extinta (ano do Censo) | 2 |

### Tabela `dominio_jurisdicao` (tabela de domínio)

Jurisdição da rodovia (federal ou estadual), conforme o SNV/DNIT. Sem geometria · Registros: **3**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `cod_jurisdicao` | char | 1 · `F`, `E`, `N` | Não | PK | Código da jurisdição (interno desta base). | E |
| `descricao` | varchar | 20 · único | Não | | Descrição da jurisdição. | Estadual |

| `cod_jurisdicao` | `descricao` | Pedaços na base |
| --- | --- | --- |
| F | Federal | 27 |
| E | Estadual | 105 |
| N | Nao informada | 16 |

### Tabela `dominio_superficie` (tabela de domínio)

Tipo de superfície do trecho rodoviário, conforme o SNV/DNIT. Sem geometria · Registros: **8**.

| Coluna | Tipo | Tam. / Domínio | Nulo? | PK / FK | Descrição | Exemplo |
| --- | --- | --- | --- | --- | --- | --- |
| `cod_superficie` | varchar | 3 · siglas do SNV, mais `N` | Não | PK | Sigla do tipo de superfície (SNV; `N` é interno desta base). | PAV |
| `descricao` | varchar | 40 · único | Não | | Descrição do tipo de superfície. | Pavimentada |

| `cod_superficie` | `descricao` | Pedaços na base |
| --- | --- | --- |
| PAV | Pavimentada | 108 |
| DUP | Pavimentada duplicada | 0 |
| IMP | Implantada (sem pavimento) | 11 |
| LEN | Leito natural | 4 |
| PLA | Planejada | 4 |
| EOP | Em obras de pavimentacao | 5 |
| EOD | Em obras de duplicacao | 0 |
| N | Nao informada | 16 |

## 4. Qualidade e limitações

- **Escolas paralisadas e extintas:** 305 das 624 escolas (cerca de 49%) não estão em atividade no Censo Escolar 2025. Elas foram mantidas para atingir o volume mínimo e porque o local continua existindo. Contagens de "rede ativa" devem filtrar `cod_situacao = 1`.
- **Coordenadas das escolas:** são as declaradas no cadastro do INEP, sem correção. Todas caem no município declarado, mas a precisão dentro do município é variável, e escolas rurais podem estar posicionadas de forma aproximada.
- **Atributos nulos:** `bairro` está vazio em 270 escolas (cerca de 43%), em geral rurais. Em `trecho_rodoviario`, 16 dos 148 pedaços (cerca de 11%) não têm código, jurisdição, superfície nem descrição na fonte.
- **Rodovias:** a camada só inclui rodovias federais e estaduais do SNV. Vias municipais, estradas vicinais e ruas urbanas não estão na base, então a distância de uma escola à "rodovia mais próxima" não é a distância de acesso real. Os dados são de 12/2021 e podem não refletir obras posteriores.
- **Atributos do trecho inteiro:** `local_inicial`, `local_final` e `codigo_snv` descrevem o trecho original do SNV, não o pedaço cortado no município.
- **Escala:** os limites municipais servem para análises regionais. Não use a base para análises cadastrais ou de vizinhança em escala detalhada.
- **Temporalidade:** as fontes têm datas diferentes: população de 2022, escolas de 2025 e rodovias de 2021. Indicadores que cruzam as camadas (por exemplo, escolas por habitante) misturam anos.
