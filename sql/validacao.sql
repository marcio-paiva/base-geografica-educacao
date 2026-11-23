-- Validacao da base depois de sql/schema.sql e sql/carga.sql.
-- Execucao: psql -d bdgeo_escolas -f sql/validacao.sql
-- Cada verificacao mostra o valor obtido, o esperado e OK/FALHA.

\set ON_ERROR_STOP on
\set QUIET on
\pset footer off

SET client_min_messages = warning;
DROP TABLE IF EXISTS resultado;
CREATE TEMP TABLE resultado (
    ordem     serial,
    grupo     text,
    verificacao text,
    obtido    text,
    esperado  text,
    ok        boolean
);

-- ---------------------------------------------------------------------------
-- 1. Contagem de registros
-- ---------------------------------------------------------------------------
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '1. contagem', t, n::text, e::text, n = e
FROM (VALUES
    ('municipio',           (SELECT count(*) FROM municipio),           18),
    ('escola',              (SELECT count(*) FROM escola),              624),
    ('trecho_rodoviario',   (SELECT count(*) FROM trecho_rodoviario),   148),
    ('dominio_dependencia', (SELECT count(*) FROM dominio_dependencia), 4),
    ('dominio_situacao',    (SELECT count(*) FROM dominio_situacao),    3),
    ('dominio_jurisdicao',  (SELECT count(*) FROM dominio_jurisdicao),  3),
    ('dominio_superficie',  (SELECT count(*) FROM dominio_superficie),  8)
) AS v(t, n, e);

INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '1. contagem', 'total de feicoes (tabelas espaciais)', n::text, '>= 500', n >= 500
FROM (SELECT (SELECT count(*) FROM municipio)
           + (SELECT count(*) FROM escola)
           + (SELECT count(*) FROM trecho_rodoviario) AS n) s;

-- ---------------------------------------------------------------------------
-- 2. Geometrias: nulas, vazias, invalidas, tipo e SRID
-- ---------------------------------------------------------------------------
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '2. geometria', tabela || ': nulas, vazias ou invalidas', n::text, '0', n = 0
FROM (
    SELECT 'municipio' AS tabela, count(*) FILTER (WHERE geom IS NULL OR ST_IsEmpty(geom) OR NOT ST_IsValid(geom)) AS n FROM municipio
    UNION ALL
    SELECT 'escola', count(*) FILTER (WHERE geom IS NULL OR ST_IsEmpty(geom) OR NOT ST_IsValid(geom)) FROM escola
    UNION ALL
    SELECT 'trecho_rodoviario', count(*) FILTER (WHERE geom IS NULL OR ST_IsEmpty(geom) OR NOT ST_IsValid(geom)) FROM trecho_rodoviario
) s;

INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '2. geometria', f_table_name || ': tipo e SRID',
       type || ', ' || srid, e,
       type || ', ' || srid = e
FROM geometry_columns
JOIN (VALUES ('municipio', 'MULTIPOLYGON, 4674'),
             ('escola', 'POINT, 4674'),
             ('trecho_rodoviario', 'MULTILINESTRING, 4674')) AS v(tabela, e)
  ON v.tabela = f_table_name
WHERE f_table_schema = 'public';

INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '2. geometria', 'tipos geometricos distintos', count(DISTINCT type)::text, '>= 2', count(DISTINCT type) >= 2
FROM geometry_columns WHERE f_table_schema = 'public';

-- ---------------------------------------------------------------------------
-- 3. Integridade referencial (as FKs ja garantem; aqui fica documentado)
-- ---------------------------------------------------------------------------
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '3. chaves', v, n::text, '0', n = 0
FROM (VALUES
    ('escola sem municipio',
        (SELECT count(*) FROM escola e LEFT JOIN municipio m USING (cod_ibge) WHERE m.cod_ibge IS NULL)),
    ('escola sem dependencia',
        (SELECT count(*) FROM escola e LEFT JOIN dominio_dependencia d USING (cod_dependencia) WHERE d.cod_dependencia IS NULL)),
    ('escola sem situacao',
        (SELECT count(*) FROM escola e LEFT JOIN dominio_situacao d USING (cod_situacao) WHERE d.cod_situacao IS NULL)),
    ('trecho sem municipio',
        (SELECT count(*) FROM trecho_rodoviario t LEFT JOIN municipio m USING (cod_ibge) WHERE m.cod_ibge IS NULL)),
    ('trecho sem jurisdicao',
        (SELECT count(*) FROM trecho_rodoviario t LEFT JOIN dominio_jurisdicao d USING (cod_jurisdicao) WHERE d.cod_jurisdicao IS NULL)),
    ('trecho sem superficie',
        (SELECT count(*) FROM trecho_rodoviario t LEFT JOIN dominio_superficie d USING (cod_superficie) WHERE d.cod_superficie IS NULL))
) AS v(v, n);

-- ---------------------------------------------------------------------------
-- 4. Relacoes espaciais documentadas no DICIONARIO.md
-- ---------------------------------------------------------------------------
-- 4.1 ST_Within(escola, municipio): o ponto cai no municipio declarado
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '4. espacial', 'escolas fora do municipio declarado', count(*)::text, '0', count(*) = 0
FROM escola e JOIN municipio m USING (cod_ibge)
WHERE NOT ST_Within(e.geom, m.geom);

-- 4.2 Cada pedaco de trecho esta no municipio declarado.
-- O corte foi feito no Python e as coordenadas foram arredondadas a 9 casas,
-- entao a conferencia usa uma tolerancia de 1 m (ST_CoveredBy no buffer).
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '4. espacial', 'trechos fora do municipio declarado (tolerancia 1 m)', count(*)::text, '0', count(*) = 0
FROM trecho_rodoviario t JOIN municipio m USING (cod_ibge)
WHERE NOT ST_CoveredBy(t.geom::geography, ST_Buffer(m.geom::geography, 1));

-- 4.3 extensao_km bate com o comprimento da geometria (diferenca < 1%)
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '4. espacial', 'extensao_km diverge do comprimento em UTM 23S (> 1%)', count(*)::text, '0', count(*) = 0
FROM trecho_rodoviario
WHERE abs(ST_Length(ST_Transform(geom, 31983)) / 1000 - extensao_km) > 0.01 * extensao_km + 0.001;

-- 4.4 area_km2 oficial x area da malha (diferenca maxima, so informativo)
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '4. espacial', 'maior diferenca area oficial x malha (%)',
       round(max(abs(ST_Area(geom::geography) / 1e6 - area_km2) / area_km2 * 100)::numeric, 2)::text, '< 1',
       max(abs(ST_Area(geom::geography) / 1e6 - area_km2) / area_km2 * 100) < 1
FROM municipio;

-- ---------------------------------------------------------------------------
-- 5. Indices espaciais GiST
-- ---------------------------------------------------------------------------
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '5. indices', tabela || ': indice GiST em geom',
       coalesce(idx, '(nenhum)'), 'presente', idx IS NOT NULL
FROM (VALUES ('municipio'), ('escola'), ('trecho_rodoviario')) AS v(tabela)
LEFT JOIN LATERAL (
    SELECT string_agg(indexname, ', ') AS idx FROM pg_indexes
    WHERE tablename = v.tabela AND indexdef ILIKE '%USING gist%(geom)%'
) i ON true;

-- ---------------------------------------------------------------------------
-- 6. Nomes em snake_case (minusculas, sem acento e sem espaco)
-- ---------------------------------------------------------------------------
INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '6. nomes', 'tabelas/colunas fora de snake_case', count(*)::text, '0', count(*) = 0
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('municipio', 'escola', 'trecho_rodoviario', 'dominio_dependencia',
                     'dominio_situacao', 'dominio_jurisdicao', 'dominio_superficie')
  AND (table_name !~ '^[a-z][a-z0-9_]*$' OR column_name !~ '^[a-z][a-z0-9_]*$');

INSERT INTO resultado (grupo, verificacao, obtido, esperado, ok)
SELECT '6. nomes', 'codificacao do banco', pg_encoding_to_char(encoding), 'UTF8',
       pg_encoding_to_char(encoding) = 'UTF8'
FROM pg_database WHERE datname = current_database();

-- ---------------------------------------------------------------------------
-- Relatorio
-- ---------------------------------------------------------------------------
\echo
\echo '== Validacao da base =='
SELECT grupo, verificacao, obtido, esperado, CASE WHEN ok THEN 'OK' ELSE 'FALHA' END AS status
FROM resultado ORDER BY ordem;

\echo
\echo '== Versoes =='
SELECT version() AS postgresql, postgis_lib_version() AS postgis;

\echo
\echo '== Resumo por municipio =='
SELECT m.nome,
       (SELECT count(*) FROM escola e WHERE e.cod_ibge = m.cod_ibge)                          AS escolas,
       (SELECT count(*) FROM escola e WHERE e.cod_ibge = m.cod_ibge AND e.cod_situacao = 1)   AS em_atividade,
       (SELECT count(*) FROM trecho_rodoviario t WHERE t.cod_ibge = m.cod_ibge)               AS trechos,
       (SELECT coalesce(round(sum(t.extensao_km), 1), 0)
          FROM trecho_rodoviario t WHERE t.cod_ibge = m.cod_ibge)                             AS km_rodovia
FROM municipio m
ORDER BY m.nome;

-- Para o script falhar (codigo de saida != 0) se alguma verificacao deu FALHA
RESET client_min_messages;
DO $$
DECLARE n int;
BEGIN
    SELECT count(*) INTO n FROM resultado WHERE NOT ok;
    IF n > 0 THEN
        RAISE EXCEPTION 'Validacao: % verificacao(oes) com FALHA', n;
    END IF;
    RAISE NOTICE 'Validacao: todas as verificacoes OK';
END $$;
