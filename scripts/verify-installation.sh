#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

ok() {
  echo "[OK] $1"
}

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1090
  source <(tr -d '\r' < .env)
  set +a
fi

POSTGRES_ADMIN_USER=${POSTGRES_ADMIN_USER:-postgres}
HIBERNATE_DB=${HIBERNATE_DB:-hibernate}
QUARTZ_DB=${QUARTZ_DB:-quartz}
JACKRABBIT_DB=${JACKRABBIT_DB:-jackrabbit}
PENTAHO_HTTP_PORT=${PENTAHO_HTTP_PORT:-8090}

docker --version >/dev/null || fail "Docker"
ok "Docker"

docker compose version >/dev/null || fail "Docker Compose"
ok "Docker Compose"

docker compose ps repository --status running | grep -q repository || fail "PostgreSQL container"
ok "PostgreSQL container"

health=$(docker inspect -f '{{.State.Health.Status}}' pentaho-repository 2>/dev/null || true)
[[ "${health}" == "healthy" ]] || fail "PostgreSQL healthy"
ok "PostgreSQL healthy"

for db in "${HIBERNATE_DB}" "${QUARTZ_DB}" "${JACKRABBIT_DB}"; do
  count=$(docker compose exec -T repository psql -U "${POSTGRES_ADMIN_USER}" -d "${db}" -Atc "select count(*) from information_schema.tables where table_schema = 'public';") || fail "Pentaho databases"
  [[ "${count}" -gt 0 ]] || fail "Pentaho databases"
done
ok "Pentaho databases"

docker compose ps pentaho-server --status running | grep -q pentaho-server || fail "Pentaho container"
ok "Pentaho container"

docker compose exec -T pentaho-server getent hosts repository >/dev/null || fail "Docker DNS"
ok "Docker DNS"

docker compose exec -T pentaho-server nc -z repository 5432 || fail "PostgreSQL connectivity"
ok "PostgreSQL connectivity"

docker compose exec -T pentaho-server curl -fsS -o /dev/null -L http://localhost:8080/pentaho/ || fail "Pentaho internal HTTP"
ok "Pentaho internal HTTP"

curl -fsS -o /dev/null -L "http://localhost:${PENTAHO_HTTP_PORT}/pentaho/" || fail "Pentaho external HTTP"
ok "Pentaho external HTTP"

echo
echo "Pentaho installation verified successfully."
