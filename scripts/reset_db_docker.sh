#!/usr/bin/env sh
# [Alternativa com Docker] Recria o banco do zero (apaga o volume) e espera o PostGIS ficar pronto.
# Uso: sh scripts/reset_db_docker.sh   (a partir da raiz do repositório)
set -e
cd "$(dirname "$0")/.."

docker compose down -v
docker compose up -d

echo "Aguardando o banco ficar pronto..."
i=0
until [ "$(docker inspect -f '{{.State.Health.Status}}' bdgeo_escolas_db 2>/dev/null)" = "healthy" ]; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then echo "Banco não ficou pronto" >&2; exit 1; fi
  sleep 2
done

docker compose exec -T db psql -U bdgeo -d bdgeo_escolas \
  -c "CREATE EXTENSION IF NOT EXISTS postgis; SELECT postgis_full_version();"
