#!/usr/bin/env bash
set -e

# The official postgres entrypoint does not expand environment variables in
# .sql files, so the replication role is created from a shell script instead.
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v replica_password="$POSTGRES_PASSWORD" <<'EOSQL'
-- Create the replication role if it does not exist yet
SELECT format('CREATE ROLE replica WITH REPLICATION LOGIN PASSWORD %L', :'replica_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replica')
\gexec

-- Keep the password in sync with POSTGRES_PASSWORD from .env
ALTER ROLE replica WITH REPLICATION LOGIN PASSWORD :'replica_password';

-- Create the physical replication slot if it does not exist yet
SELECT pg_create_physical_replication_slot('replica_slot', true)
WHERE NOT EXISTS (SELECT FROM pg_replication_slots WHERE slot_name = 'replica_slot');
EOSQL
