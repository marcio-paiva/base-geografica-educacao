<#
Recria o banco do zero num PostgreSQL local (portátil ou instalado) e habilita o PostGIS.
Serve para o teste de importação em banco limpo exigido no enunciado.

Uso (a partir da raiz do repositório, com o servidor no ar):
  .\scripts\reset_db.ps1

Os binários são procurados em $env:PGBIN, depois no PostgreSQL portátil
($env:PGPORTATIL ou $HOME\pgsql\pgsql\bin) e por fim no PATH.
Conexão: localhost, porta $env:POSTGRES_PORT (padrão 5433), usuário e senha do .env.example.
Com Docker, use .\scripts\reset_db_docker.ps1.
#>
$ErrorActionPreference = 'Stop'

$candidatos = @()
if ($env:PGBIN) { $candidatos += $env:PGBIN }
$raizPortatil = if ($env:PGPORTATIL) { $env:PGPORTATIL } else { Join-Path $HOME 'pgsql' }
$candidatos += Join-Path $raizPortatil 'pgsql\bin'
$bin = $candidatos | Where-Object { Test-Path (Join-Path $_ 'psql.exe') } | Select-Object -First 1
if (-not $bin) {
    $psql = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psql) { throw 'psql não encontrado. Rode .\scripts\pg_portatil.ps1 instalar ou defina $env:PGBIN.' }
    $bin = Split-Path $psql.Source
}

$env:PGHOST = 'localhost'
$env:PGPORT = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { '5433' }
$env:PGUSER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { 'bdgeo' }
$env:PGPASSWORD = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { 'bdgeo' }
$banco = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { 'bdgeo_escolas' }

& (Join-Path $bin 'dropdb.exe') --if-exists --force --maintenance-db=postgres $banco
if ($LASTEXITCODE -ne 0) { throw 'dropdb falhou (o servidor está no ar?)' }
& (Join-Path $bin 'createdb.exe') -E UTF8 -T template0 $banco
if ($LASTEXITCODE -ne 0) { throw 'createdb falhou' }
& (Join-Path $bin 'psql.exe') -v ON_ERROR_STOP=1 -d $banco -c "CREATE EXTENSION IF NOT EXISTS postgis;" -c "SELECT version();" -c "SELECT postgis_full_version();"
if ($LASTEXITCODE -ne 0) { throw 'Falha ao habilitar o PostGIS' }
Write-Host "Banco '$banco' recriado do zero com PostGIS."
