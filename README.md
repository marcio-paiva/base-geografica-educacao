# Base geográfica de escolas – Microrregião de Itabira (MG)

Trabalho de CSI803 – Banco de Dados Geográficos (UFOP). **Em andamento:** este README será completado nas próximas etapas.

## Situação

| Etapa | Situação |
| --- | --- |
| 1. Ambiente | Concluída: PostgreSQL 16.15 + PostGIS 3.7.0 (portátil ou Docker), Python 3.11 |
| 2. Coleta | Concluída: 18 municípios, 624 escolas, 148 trechos de rodovia no recorte (790 feições) |
| 3. Tratamento | Concluída: `scripts/tratamento/tratar.py` gera `dados/tratados/*.csv` (EWKT, EPSG:4674); log em `scripts/log_tratamento.txt` |
| 4. Schema | Concluída: `sql/schema.sql` (3 tabelas espaciais + 4 de domínio) e `sql/carga.sql` (`\copy`), testados em banco limpo no Docker |
| 5. Carga e validação | Concluída: `sql/validacao.sql` (30 verificações, todas OK) em banco limpo com PostgreSQL 16.15 + PostGIS 3.4.2 |
| 6. Documentação | Pendente |
| 7. Publicação | Pendente |

## Por onde começar

- [docs/AMBIENTE.md](docs/AMBIENTE.md): como montar o banco e o Python e como rodar a coleta.
- [dados/brutos/FONTES.md](dados/brutos/FONTES.md): fonte, data de coleta, versão, licença e hash de cada arquivo baixado.
- `dados/brutos/contagem_preliminar.json`: contagem de feições por camada dentro do recorte.

## Tratamento e carga (etapas 3 e 4)

```powershell
# 1. Tratamento (a partir da raiz): dados/brutos -> dados/tratados
python scripts/tratamento/tratar.py

# 2. Banco limpo no Docker, schema e carga
docker compose down -v; docker compose up -d
docker compose exec -w /repo db psql -U bdgeo -d bdgeo_escolas -f sql/schema.sql
docker compose exec -w /repo db psql -U bdgeo -d bdgeo_escolas -f sql/carga.sql
docker compose exec -w /repo db psql -U bdgeo -d bdgeo_escolas -f sql/validacao.sql
```

O `sql/validacao.sql` confere contagens, geometrias (nulas, vazias, inválidas, tipo e SRID), chaves estrangeiras, as relações espaciais documentadas (escolas e trechos dentro do município declarado), `extensao_km`, índices GiST, snake_case e UTF-8. Ele mostra um relatório OK/FALHA e termina com erro se alguma verificação falhar.

Resultado: 18 municípios, 624 escolas e 148 trechos rodoviários (790 feições). Modelo:

| Tabela | Geometria | Ligação |
| --- | --- | --- |
| `municipio` | MultiPolygon | PK `cod_ibge` |
| `escola` | Point | FK `cod_ibge`, `cod_dependencia`, `cod_situacao` |
| `trecho_rodoviario` | MultiLineString | FK `cod_ibge`, `cod_jurisdicao`, `cod_superficie` |
| `dominio_*` (4) | sem geometria | dependência, situação, jurisdição, superfície |

Principais decisões do tratamento:

- Rodovias são cortadas pelo limite de cada município; `extensao_km` é o comprimento do pedaço, medido em UTM 23S (EPSG:31983).
- 16 trechos do shapefile não têm jurisdição, superfície nem código; ficam com `N` (não informada) nos domínios e `codigo` nulo.
- `codigo` da rodovia = prefixo da jurisdição (`BR-`/`MG-`) + `codigo_rod` do SNV.
- As coordenadas das escolas não foram alteradas: as 624 caem dentro do município declarado.
- Porte da escola, previsto no plano, não existe na fonte e não foi incluído.

## Decisões já tomadas

- Recorte: microrregião de Itabira (IBGE 31031, 18 municípios). A Região Imediata de João Monlevade tinha só 6 municípios e não chegava a 500 feições.
- SRID: EPSG:4674 (SIRGAS 2000).
- Escolas: INEP via geobr, Censo Escolar 2025, mantendo as paralisadas (sem elas o total cai para 485).
- Rodovias: IDE-Sisema/DNIT, recortadas por município no tratamento.
