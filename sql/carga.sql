-- Carga dos CSV tratados (geometria em EWKT) com \copy.
-- Execute a partir da RAIZ do repositorio, depois de sql/schema.sql:
--   psql -d bdgeo_escolas -f sql/schema.sql
--   psql -d bdgeo_escolas -f sql/carga.sql
\set ON_ERROR_STOP on
\encoding UTF8

\copy dominio_dependencia (cod_dependencia, descricao) FROM 'dados/tratados/dominio_dependencia.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy dominio_situacao (cod_situacao, descricao) FROM 'dados/tratados/dominio_situacao.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy dominio_jurisdicao (cod_jurisdicao, descricao) FROM 'dados/tratados/dominio_jurisdicao.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy dominio_superficie (cod_superficie, descricao) FROM 'dados/tratados/dominio_superficie.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy municipio (cod_ibge, nome, uf, regiao_imediata, area_km2, populacao, geom) FROM 'dados/tratados/municipio.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy escola (cod_inep, nome, cod_ibge, cod_dependencia, cod_situacao, localizacao, endereco, bairro, cep, geom) FROM 'dados/tratados/escola.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy trecho_rodoviario (id_trecho, cod_ibge, codigo, codigo_snv, tipo_trecho, local_inicial, local_final, cod_jurisdicao, cod_superficie, extensao_km, geom) FROM 'dados/tratados/trecho_rodoviario.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

ANALYZE;
