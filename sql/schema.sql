-- Esquema da base geografica de escolas da Microrregiao de Itabira (MG)
-- PostgreSQL 16 + PostGIS 3.x. Todas as geometrias em EPSG:4674 (SIRGAS 2000).
-- Execucao: psql -d bdgeo_escolas -f sql/schema.sql

CREATE EXTENSION IF NOT EXISTS postgis;

-- Recria do zero (permite rodar o script mais de uma vez)
DROP TABLE IF EXISTS trecho_rodoviario, escola, municipio,
                     dominio_dependencia, dominio_situacao,
                     dominio_jurisdicao, dominio_superficie CASCADE;

-- ---------------------------------------------------------------------------
-- Tabelas de dominio (sem geometria)
-- ---------------------------------------------------------------------------
CREATE TABLE dominio_dependencia (
    cod_dependencia smallint     PRIMARY KEY,
    descricao       varchar(30)  NOT NULL UNIQUE
);
COMMENT ON TABLE dominio_dependencia IS 'Dependencia administrativa da escola (codigos do Censo Escolar/INEP).';

CREATE TABLE dominio_situacao (
    cod_situacao smallint     PRIMARY KEY,
    descricao    varchar(40)  NOT NULL UNIQUE
);
COMMENT ON TABLE dominio_situacao IS 'Situacao de funcionamento da escola no Censo Escolar.';

CREATE TABLE dominio_jurisdicao (
    cod_jurisdicao char(1)      PRIMARY KEY,
    descricao      varchar(20)  NOT NULL UNIQUE
);
COMMENT ON TABLE dominio_jurisdicao IS 'Jurisdicao da rodovia (federal, estadual) conforme o SNV/DNIT.';

CREATE TABLE dominio_superficie (
    cod_superficie varchar(3)   PRIMARY KEY,
    descricao      varchar(40)  NOT NULL UNIQUE
);
COMMENT ON TABLE dominio_superficie IS 'Tipo de superficie do trecho rodoviario conforme o SNV/DNIT.';

-- ---------------------------------------------------------------------------
-- municipio: MultiPolygon
-- ---------------------------------------------------------------------------
CREATE TABLE municipio (
    cod_ibge         integer                       PRIMARY KEY,
    nome             varchar(60)                   NOT NULL,
    uf               char(2)                       NOT NULL,
    regiao_imediata  varchar(60)                   NOT NULL,
    area_km2         numeric(10,3)                 NOT NULL,
    populacao        integer                       NOT NULL,
    geom             geometry(MultiPolygon, 4674)  NOT NULL,
    CONSTRAINT uq_municipio_nome_uf   UNIQUE (nome, uf),
    CONSTRAINT ck_municipio_cod_ibge  CHECK (cod_ibge BETWEEN 1000000 AND 5999999),
    CONSTRAINT ck_municipio_uf        CHECK (uf ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_municipio_area      CHECK (area_km2 > 0),
    CONSTRAINT ck_municipio_populacao CHECK (populacao >= 0),
    CONSTRAINT ck_municipio_geom      CHECK (ST_IsValid(geom) AND NOT ST_IsEmpty(geom))
);
CREATE INDEX idx_municipio_geom ON municipio USING GIST (geom);
COMMENT ON TABLE municipio IS 'Municipios da microrregiao de Itabira (IBGE 31031). Malha IBGE e Censo 2022.';

-- ---------------------------------------------------------------------------
-- escola: Point
-- ---------------------------------------------------------------------------
CREATE TABLE escola (
    cod_inep         bigint                  PRIMARY KEY,
    nome             varchar(150)            NOT NULL,
    cod_ibge         integer                 NOT NULL REFERENCES municipio (cod_ibge),
    cod_dependencia  smallint                NOT NULL REFERENCES dominio_dependencia (cod_dependencia),
    cod_situacao     smallint                NOT NULL REFERENCES dominio_situacao (cod_situacao),
    localizacao      varchar(7)              NOT NULL,
    endereco         varchar(200)            NOT NULL,
    bairro           varchar(100),
    cep              char(8),
    geom             geometry(Point, 4674)   NOT NULL,
    CONSTRAINT ck_escola_cod_inep    CHECK (cod_inep BETWEEN 10000000 AND 99999999),
    CONSTRAINT ck_escola_localizacao CHECK (localizacao IN ('urbana', 'rural')),
    CONSTRAINT ck_escola_cep         CHECK (cep ~ '^[0-9]{8}$'),
    CONSTRAINT ck_escola_geom        CHECK (ST_IsValid(geom) AND NOT ST_IsEmpty(geom))
);
CREATE INDEX idx_escola_geom         ON escola USING GIST (geom);
CREATE INDEX idx_escola_cod_ibge     ON escola (cod_ibge);
CREATE INDEX idx_escola_dependencia  ON escola (cod_dependencia);
COMMENT ON TABLE escola IS 'Escolas do Censo Escolar 2025 (INEP) nos municipios do recorte, com coordenada do cadastro do INEP.';

-- ---------------------------------------------------------------------------
-- trecho_rodoviario: MultiLineString (cada trecho cortado pelo limite do municipio)
-- ---------------------------------------------------------------------------
CREATE TABLE trecho_rodoviario (
    id_trecho       integer                          PRIMARY KEY,
    cod_ibge        integer                          NOT NULL REFERENCES municipio (cod_ibge),
    codigo          varchar(10),
    codigo_snv      varchar(15),
    tipo_trecho     varchar(20),
    local_inicial   varchar(100),
    local_final     varchar(100),
    cod_jurisdicao  char(1)                          NOT NULL REFERENCES dominio_jurisdicao (cod_jurisdicao),
    cod_superficie  varchar(3)                       NOT NULL REFERENCES dominio_superficie (cod_superficie),
    extensao_km     numeric(8,3)                     NOT NULL,
    geom            geometry(MultiLineString, 4674)  NOT NULL,
    CONSTRAINT ck_trecho_extensao CHECK (extensao_km > 0),
    CONSTRAINT ck_trecho_geom     CHECK (ST_IsValid(geom) AND NOT ST_IsEmpty(geom))
);
CREATE INDEX idx_trecho_geom     ON trecho_rodoviario USING GIST (geom);
CREATE INDEX idx_trecho_cod_ibge ON trecho_rodoviario (cod_ibge);
COMMENT ON TABLE trecho_rodoviario IS 'Rodovias federais e estaduais (SNV/DNIT via IDE-Sisema) cortadas pelo limite de cada municipio.';
COMMENT ON COLUMN trecho_rodoviario.extensao_km IS 'Comprimento do pedaco dentro do municipio, calculado em UTM 23S (EPSG:31983).';
