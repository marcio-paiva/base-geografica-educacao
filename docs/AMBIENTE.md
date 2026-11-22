# Ambiente de desenvolvimento

Etapa 1 do trabalho. Este passo a passo foi testado em 2026-11-22 no Windows 11, sem Docker
(a máquina de teste está com a virtualização desativada).

## Versões testadas

| Componente | Versão |
| --- | --- |
| PostgreSQL | 16.15 (binários EDB para Windows x64) |
| PostGIS | 3.7.0 (GEOS 3.15.0, PROJ 9.8.1) |
| Python | 3.11 |
| Pacotes Python | ver `requirements.txt` (geobr 2.1.1, geopandas 1.2.0, pyogrio 0.13.0 com GDAL 3.12.4) |

## Banco: PostgreSQL + PostGIS portáteis (caminho principal)

Não precisa de instalador, de administrador nem de Docker. Por padrão tudo fica em `%USERPROFILE%\pgsql`;
para mudar, defina `$env:PGPORTATIL` com um caminho **curto**.

```powershell
.\scripts\pg_portatil.ps1 instalar   # baixa PostgreSQL 16.15 (332 MB) e PostGIS 3.7.0 (84 MB), cria o cluster
.\scripts\pg_portatil.ps1 iniciar    # servidor em localhost:5433
.\scripts\reset_db.ps1               # recria o banco bdgeo_escolas do zero, com PostGIS
.\scripts\pg_portatil.ps1 parar      # ao terminar
```

Conexão: `localhost`, porta `5433`, banco `bdgeo_escolas`, usuário e senha `bdgeo` (ver `.env.example`).
O `reset_db.ps1` também serve para o teste de importação em banco limpo exigido no enunciado.

Quem já tem PostgreSQL instalado pode pular o `pg_portatil.ps1`: defina `$env:PGBIN` com a pasta `bin`
e ajuste `$env:POSTGRES_PORT` se o servidor estiver na porta 5432.

## Banco: alternativa com Docker

Para quem tem Docker Desktop funcionando (`postgis/postgis:16-3.7`):

```powershell
Copy-Item .env.example .env
.\scripts\reset_db_docker.ps1        # ou: sh scripts/reset_db_docker.sh
```

## Python

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements.txt
```

Se o repositório estiver num caminho muito longo, o import do `shapely` falha com
"The filename or extension is too long". Nesse caso crie o ambiente virtual num caminho curto
(por exemplo `C:\venvs\bdgeo`) e use esse Python para rodar os scripts.

## Coleta (etapa 2)

```powershell
cd scripts\coleta
python 01_municipios.py   # IBGE: lista, malha e Censo 2022 (SIDRA 4714)
python 02_escolas.py      # INEP via geobr: escolas de MG, Censo Escolar 2025
python 03_rodovias.py     # IDE-Sisema/DNIT: rodovias de MG (WFS)
python 04_contagem.py     # contagem no recorte + dados/brutos/FONTES.md
```

As fontes, licenças e hashes dos arquivos baixados estão em [`dados/brutos/FONTES.md`](../dados/brutos/FONTES.md).

## Problemas conhecidos

- O geobr 2.1.1 não funciona com duckdb 2.x; o `requirements.txt` fixa `duckdb==1.5.6`.
- O Windows PowerShell 5.1 só lê acentos dos `.ps1` corretamente porque os scripts estão salvos em UTF-8 com BOM.
