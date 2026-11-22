# [Alternativa com Docker] Recria o banco do zero (apaga o volume) e espera o PostGIS ficar pronto.
# Uso: .\scripts\reset_db_docker.ps1  (a partir da raiz do repositório)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

docker compose down -v
docker compose up -d

Write-Host 'Aguardando o banco ficar pronto...'
for ($i = 0; $i -lt 60; $i++) {
    $status = docker inspect -f '{{.State.Health.Status}}' bdgeo_escolas_db 2>$null
    if ($status -eq 'healthy') { break }
    Start-Sleep -Seconds 2
}
if ($status -ne 'healthy') { throw "Banco não ficou pronto (status: $status)" }

docker compose exec -T db psql -U bdgeo -d bdgeo_escolas -c "CREATE EXTENSION IF NOT EXISTS postgis; SELECT postgis_full_version();"
