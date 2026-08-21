#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  POSTGRES_USER HIBERNATE_DB HIBERNATE_USER HIBERNATE_PASSWORD
  QUARTZ_DB QUARTZ_USER QUARTZ_PASSWORD
  JACKRABBIT_DB JACKRABBIT_USER JACKRABBIT_PASSWORD
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required environment variable: ${var}" >&2
    exit 1
  fi
done

if [[ "${HIBERNATE_DB}" != "hibernate" || "${HIBERNATE_USER}" != "hibuser" || "${QUARTZ_DB}" != "quartz" || "${QUARTZ_USER}" != "pentaho_user" || "${JACKRABBIT_DB}" != "jackrabbit" || "${JACKRABBIT_USER}" != "jcr_user" ]]; then
  echo "This Pentaho CE distribution ships PostgreSQL scripts for hibernate/hibuser, quartz/pentaho_user and jackrabbit/jcr_user. Keep those names unless the SQL scripts are reviewed and adapted." >&2
  exit 1
fi

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname postgres <<SQL
CREATE USER ${HIBERNATE_USER} PASSWORD '${HIBERNATE_PASSWORD}';
CREATE DATABASE ${HIBERNATE_DB} WITH OWNER = ${HIBERNATE_USER} ENCODING = 'UTF8' TABLESPACE = pg_default;
GRANT ALL PRIVILEGES ON DATABASE ${HIBERNATE_DB} TO ${HIBERNATE_USER};

CREATE USER ${QUARTZ_USER} PASSWORD '${QUARTZ_PASSWORD}';
CREATE DATABASE ${QUARTZ_DB} WITH OWNER = ${QUARTZ_USER} ENCODING = 'UTF8' TABLESPACE = pg_default;
GRANT ALL PRIVILEGES ON DATABASE ${QUARTZ_DB} TO ${QUARTZ_USER};

CREATE USER ${JACKRABBIT_USER} PASSWORD '${JACKRABBIT_PASSWORD}';
CREATE DATABASE ${JACKRABBIT_DB} WITH OWNER = ${JACKRABBIT_USER} ENCODING = 'UTF8' TABLESPACE = pg_default;
GRANT ALL PRIVILEGES ON DATABASE ${JACKRABBIT_DB} TO ${JACKRABBIT_USER};
SQL

awk 'found { print } /^begin;$/ { found=1; print }' \
  /opt/pentaho-sql/pentaho-server/data/postgresql/create_quartz_postgresql.sql \
  | psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${QUARTZ_DB}"
