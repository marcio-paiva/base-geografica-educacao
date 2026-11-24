-- Consultas espaciais de exemplo da base geografica de escolas da
-- Microrregiao de Itabira (MG).
-- Execucao (depois de schema.sql e carga.sql):
--   psql -d bdgeo_escolas -f sql/consultas.sql
--
-- Todas as geometrias estao em EPSG:4674 (graus). Distancias e comprimentos
-- em metros usam geography (ou EPSG:31983, UTM 23S), nunca graus.
-- Lembrete: 305 das 624 escolas nao estao em atividade (cod_situacao <> 1);
-- as consultas de "rede ativa" filtram cod_situacao = 1.

\pset null '(nulo)'

-- ---------------------------------------------------------------------------
-- 1. Resumo por municipio: escolas, escolas em atividade, escolas rurais,
--    trechos e quilometros de rodovia
-- ---------------------------------------------------------------------------
\echo
\echo '== 1. Resumo por municipio =='
SELECT m.nome,
       m.regiao_imediata,
       m.populacao,
       (SELECT count(*) FROM escola e
         WHERE e.cod_ibge = m.cod_ibge)                                  AS escolas,
       (SELECT count(*) FROM escola e
         WHERE e.cod_ibge = m.cod_ibge AND e.cod_situacao = 1)           AS em_atividade,
       (SELECT count(*) FROM escola e
         WHERE e.cod_ibge = m.cod_ibge AND e.localizacao = 'rural')      AS rurais,
       (SELECT count(*) FROM trecho_rodoviario t
         WHERE t.cod_ibge = m.cod_ibge)                                  AS trechos,
       (SELECT coalesce(round(sum(t.extensao_km), 1), 0)
          FROM trecho_rodoviario t WHERE t.cod_ibge = m.cod_ibge)        AS km_rodovia
FROM municipio m
ORDER BY escolas DESC, m.nome;

-- ---------------------------------------------------------------------------
-- 2. Escolas por dependencia administrativa e localizacao (so em atividade)
-- ---------------------------------------------------------------------------
\echo
\echo '== 2. Escolas em atividade por dependencia e localizacao =='
SELECT d.descricao AS dependencia,
       count(*) FILTER (WHERE e.localizacao = 'urbana') AS urbanas,
       count(*) FILTER (WHERE e.localizacao = 'rural')  AS rurais,
       count(*)                                         AS total
FROM escola e
JOIN dominio_dependencia d USING (cod_dependencia)
WHERE e.cod_situacao = 1
GROUP BY d.cod_dependencia, d.descricao
ORDER BY d.cod_dependencia;

-- ---------------------------------------------------------------------------
-- 3. ST_Within: confere o municipio declarado no cadastro (esperado: 0 linhas)
-- ---------------------------------------------------------------------------
\echo
\echo '== 3. Escolas fora do municipio declarado (esperado: nenhuma) =='
SELECT e.cod_inep, e.nome, e.cod_ibge AS cod_ibge_declarado
FROM escola e
JOIN municipio m ON m.cod_ibge = e.cod_ibge
WHERE NOT ST_Within(e.geom, m.geom);

-- Descobre o municipio de uma escola so pela geometria (join espacial) e
-- compara com o declarado. Util se a carga futura vier sem cod_ibge.
\echo
\echo '== 3b. Municipio por join espacial x declarado (divergencias) =='
SELECT e.cod_inep, e.nome,
       e.cod_ibge AS declarado,
       m.cod_ibge AS pela_geometria
FROM escola e
JOIN municipio m ON ST_Within(e.geom, m.geom)
WHERE m.cod_ibge <> e.cod_ibge;

-- ---------------------------------------------------------------------------
-- 4. ST_DWithin sobre geography: escolas rurais em atividade a mais de 5 km
--    de qualquer rodovia federal ou estadual do SNV
-- ---------------------------------------------------------------------------
\echo
\echo '== 4. Escolas rurais em atividade a mais de 5 km de rodovia =='
SELECT e.cod_inep, e.nome, m.nome AS municipio
FROM escola e
JOIN municipio m USING (cod_ibge)
WHERE e.localizacao = 'rural'
  AND e.cod_situacao = 1
  AND NOT EXISTS (
        SELECT 1
        FROM trecho_rodoviario t
        WHERE ST_DWithin(e.geom::geography, t.geom::geography, 5000)
      )
ORDER BY m.nome, e.nome;
-- Como o cast para geography nao usa o indice GiST de geom, esta consulta
-- varre as 148 geometrias para cada escola. Com 624 escolas isso e rapido.
-- A rodovia mais proxima NAO e o acesso real: vias vicinais e municipais nao
-- estao na base (ver DICIONARIO.md, secao 4).

-- ---------------------------------------------------------------------------
-- 5. Distancia (em metros) de cada escola rural em atividade ate a rodovia
--    mais proxima. O operador <-> usa o indice GiST para pegar 5 candidatas
--    (ordenacao em graus, aproximada); a distancia final e medida em metros
--    com geography entre as candidatas.
-- ---------------------------------------------------------------------------
\echo
\echo '== 5. Rodovia mais proxima de cada escola rural em atividade =='
SELECT e.cod_inep,
       e.nome,
       m.nome                      AS municipio,
       r.codigo                    AS rodovia,
       round(r.dist_m::numeric)    AS distancia_m
FROM escola e
JOIN municipio m USING (cod_ibge)
CROSS JOIN LATERAL (
    SELECT c.codigo,
           ST_Distance(e.geom::geography, c.geom::geography) AS dist_m
    FROM (
        SELECT t.codigo, t.geom
        FROM trecho_rodoviario t
        ORDER BY t.geom <-> e.geom
        LIMIT 5
    ) c
    ORDER BY dist_m
    LIMIT 1
) r
WHERE e.localizacao = 'rural'
  AND e.cod_situacao = 1
ORDER BY r.dist_m DESC
LIMIT 20;

-- ---------------------------------------------------------------------------
-- 6. Rodovias por municipio: extensao total (km) por jurisdicao e superficie
-- ---------------------------------------------------------------------------
\echo
\echo '== 6. Extensao de rodovias por municipio, jurisdicao e superficie =='
SELECT m.nome AS municipio,
       j.descricao AS jurisdicao,
       s.descricao AS superficie,
       count(*)                       AS pedacos,
       round(sum(t.extensao_km), 1)   AS km
FROM trecho_rodoviario t
JOIN municipio m          USING (cod_ibge)
JOIN dominio_jurisdicao j USING (cod_jurisdicao)
JOIN dominio_superficie s USING (cod_superficie)
GROUP BY m.nome, j.descricao, s.descricao
ORDER BY m.nome, j.descricao, s.descricao;

-- ---------------------------------------------------------------------------
-- 7. Rodovias que atravessam mais de um municipio (um trecho do SNV cortado
--    pelo limite municipal aparece em varios registros)
-- ---------------------------------------------------------------------------
\echo
\echo '== 7. Rodovias que cruzam mais de um municipio =='
SELECT t.codigo,
       count(DISTINCT t.cod_ibge)                   AS municipios,
       string_agg(DISTINCT m.nome, ', ' ORDER BY m.nome) AS lista,
       round(sum(t.extensao_km), 1)                 AS km_no_recorte
FROM trecho_rodoviario t
JOIN municipio m USING (cod_ibge)
WHERE t.codigo IS NOT NULL
GROUP BY t.codigo
HAVING count(DISTINCT t.cod_ibge) > 1
ORDER BY municipios DESC, km_no_recorte DESC;

-- ---------------------------------------------------------------------------
-- 8. ST_DWithin: escolas em atividade a ate 1 km de rodovia, por municipio
-- ---------------------------------------------------------------------------
\echo
\echo '== 8. Escolas em atividade a ate 1 km de rodovia, por municipio =='
SELECT m.nome AS municipio,
       count(*) AS em_atividade,
       count(*) FILTER (WHERE EXISTS (
            SELECT 1 FROM trecho_rodoviario t
            WHERE ST_DWithin(e.geom::geography, t.geom::geography, 1000)
       )) AS ate_1km_de_rodovia
FROM escola e
JOIN municipio m USING (cod_ibge)
WHERE e.cod_situacao = 1
GROUP BY m.cod_ibge, m.nome
ORDER BY m.nome;

-- ---------------------------------------------------------------------------
-- 9. Densidade da rede: escolas em atividade por 100 km2 e por 10 mil hab.
--    Atencao: mistura escolas de 2025 com populacao de 2022.
-- ---------------------------------------------------------------------------
\echo
\echo '== 9. Densidade de escolas em atividade por municipio =='
SELECT m.nome,
       count(e.cod_inep)                                         AS escolas_ativas,
       round(count(e.cod_inep) / m.area_km2 * 100, 2)            AS por_100_km2,
       round(count(e.cod_inep)::numeric / m.populacao * 10000, 2) AS por_10_mil_hab
FROM municipio m
LEFT JOIN escola e ON e.cod_ibge = m.cod_ibge AND e.cod_situacao = 1
GROUP BY m.cod_ibge, m.nome, m.area_km2, m.populacao
ORDER BY por_10_mil_hab DESC;

-- ---------------------------------------------------------------------------
-- 10. Municipios vizinhos dentro do recorte: quantos municipios tocam cada
--     um (ST_Touches) e quais sao
-- ---------------------------------------------------------------------------
\echo
\echo '== 10. Municipios vizinhos (ST_Touches) =='
SELECT a.nome AS municipio, count(b.cod_ibge) AS vizinhos_no_recorte,
       string_agg(b.nome, ', ' ORDER BY b.nome) AS lista
FROM municipio a
LEFT JOIN municipio b ON a.cod_ibge <> b.cod_ibge AND ST_Touches(a.geom, b.geom)
GROUP BY a.cod_ibge, a.nome
ORDER BY vizinhos_no_recorte DESC, a.nome;
