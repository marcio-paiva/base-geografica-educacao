<#
PostgreSQL + PostGIS portáteis no Windows, sem instalador, sem administrador e sem Docker.

Uso (a partir da raiz do repositório):
  .\scripts\pg_portatil.ps1 instalar   # baixa e extrai PostgreSQL 16.15 + PostGIS 3.7.0, cria o cluster
  .\scripts\pg_portatil.ps1 iniciar    # sobe o servidor na porta 5433
  .\scripts\pg_portatil.ps1 parar      # desliga o servidor
  .\scripts\pg_portatil.ps1 status

Pasta de instalação: $env:PGPORTATIL ou, por padrão, $HOME\pgsql.
Use um caminho curto: caminhos longos quebram o carregamento de DLLs no Windows.
Credenciais: as mesmas do .env.example (banco local de desenvolvimento).
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('instalar', 'iniciar', 'parar', 'status')]
    [string]$Acao
)
$ErrorActionPreference = 'Stop'

$PG_VERSAO = '16.15-1'
$POSTGIS_VERSAO = '3.7.0'
$URL_PG = "https://get.enterprisedb.com/postgresql/postgresql-$PG_VERSAO-windows-x64-binaries.zip"
$URL_POSTGIS = "https://download.osgeo.org/postgis/windows/pg16/postgis-bundle-pg16-${POSTGIS_VERSAO}x64.zip"

$RAIZ = if ($env:PGPORTATIL) { $env:PGPORTATIL } else { Join-Path $HOME 'pgsql' }
$DOWNLOADS = Join-Path $RAIZ '_downloads'
$PGHOME = Join-Path $RAIZ 'pgsql'
$BIN = Join-Path $PGHOME 'bin'
$DADOS = Join-Path $RAIZ 'data'
$LOG = Join-Path $RAIZ 'postgres.log'

$PORTA = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { '5433' }
$USUARIO = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { 'bdgeo' }
$SENHA = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { 'bdgeo' }

function Get-Arquivo([string]$url, [string]$destino) {
    if (Test-Path $destino) { Write-Host "  já baixado: $destino"; return }
    Write-Host "  baixando $url"
    curl.exe -fL --retry 3 -o $destino $url
    if ($LASTEXITCODE -ne 0) { throw "Falha ao baixar $url" }
}

switch ($Acao) {
    'instalar' {
        New-Item -ItemType Directory -Force $DOWNLOADS | Out-Null
        $zipPg = Join-Path $DOWNLOADS (Split-Path $URL_PG -Leaf)
        $zipPostgis = Join-Path $DOWNLOADS (Split-Path $URL_POSTGIS -Leaf)
        Get-Arquivo $URL_PG $zipPg
        Get-Arquivo $URL_POSTGIS $zipPostgis

        if (-not (Test-Path (Join-Path $BIN 'postgres.exe'))) {
            Write-Host 'Extraindo PostgreSQL...'
            tar.exe -xf $zipPg -C $RAIZ
            if ($LASTEXITCODE -ne 0) { throw 'Falha ao extrair o PostgreSQL' }
        }
        if (-not (Test-Path (Join-Path $PGHOME 'share\extension\postgis.control'))) {
            Write-Host 'Extraindo PostGIS e copiando para a pasta do PostgreSQL...'
            $tmp = Join-Path $RAIZ '_postgis_tmp'
            New-Item -ItemType Directory -Force $tmp | Out-Null
            tar.exe -xf $zipPostgis -C $tmp
            if ($LASTEXITCODE -ne 0) { throw 'Falha ao extrair o PostGIS' }
            $bundle = Get-ChildItem $tmp -Directory | Select-Object -First 1
            foreach ($sub in 'bin', 'lib', 'share', 'gdal-data', 'utils') {
                $origem = Join-Path $bundle.FullName $sub
                if (Test-Path $origem) { Copy-Item -Recurse -Force (Join-Path $origem '*') (Join-Path $PGHOME $sub) }
            }
            Remove-Item -Recurse -Force $tmp
        }
        if (-not (Test-Path (Join-Path $DADOS 'PG_VERSION'))) {
            Write-Host 'Criando o cluster de dados...'
            $pwfile = Join-Path $RAIZ '_pwfile.txt'
            Set-Content -Path $pwfile -Value $SENHA -NoNewline -Encoding ascii
            & (Join-Path $BIN 'initdb.exe') -D $DADOS -U $USUARIO --pwfile=$pwfile -E UTF8 --locale=C -A scram-sha-256
            $codigo = $LASTEXITCODE
            Remove-Item $pwfile
            if ($codigo -ne 0) { throw 'initdb falhou' }
        }
        Write-Host "Pronto. PostgreSQL em $PGHOME, dados em $DADOS."
        Write-Host 'Próximo passo: .\scripts\pg_portatil.ps1 iniciar'
    }
    'iniciar' {
        & (Join-Path $BIN 'pg_ctl.exe') -D $DADOS -l $LOG -o "-p $PORTA" -w start
        if ($LASTEXITCODE -ne 0) { throw "Servidor não iniciou; veja $LOG" }
    }
    'parar' {
        & (Join-Path $BIN 'pg_ctl.exe') -D $DADOS -m fast -w stop
    }
    'status' {
        & (Join-Path $BIN 'pg_ctl.exe') -D $DADOS status
    }
}
