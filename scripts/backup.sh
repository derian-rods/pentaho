#!/usr/bin/env bash
set -euo pipefail

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1090
  source <(tr -d '\r' < .env)
  set +a
fi

timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="backups/${timestamp}"
mkdir -p "${backup_dir}"

for db in "${HIBERNATE_DB:-hibernate}" "${QUARTZ_DB:-quartz}" "${JACKRABBIT_DB:-jackrabbit}"; do
  docker compose exec -T repository pg_dump -U "${POSTGRES_ADMIN_USER:-postgres}" "${db}" > "${backup_dir}/${db}.sql"
done

echo "Backups written to ${backup_dir}"
