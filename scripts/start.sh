#!/bin/sh
set -e
DB=/data/docuseal/db.sqlite3
mkdir -p /data/docuseal

# Litestream replicates to the prod R2 path (litestream.yml). Only production may
# touch it. A Railway PR-preview / staging env clones production's R2_* creds, so
# without this guard it would restore prod data and replicate its own writes back
# over the prod backup — silent data loss. Non-prod envs run an ephemeral local
# DB, no R2.
if [ "$RAILWAY_ENVIRONMENT_NAME" != "production" ]; then
  echo "[start.sh] env=${RAILWAY_ENVIRONMENT_NAME:-local}: skipping Litestream (ephemeral DB, no R2)."
  exec /app/bin/bundle exec puma -C /app/config/puma.rb --dir /app
fi

if [ ! -f "$DB" ]; then
  echo "[start.sh] DB missing — restoring from R2 via litestream..."
  # Hard-fail on a real restore failure rather than silently booting an empty DB:
  # docuseal is the legal signing/audit record, and starting blank would replicate
  # the empty DB back over the R2 backup. `-if-replica-exists` already no-ops the
  # legitimate first-ever boot (no replica yet), so reaching here with an error
  # means the backup exists but couldn't be restored — refuse to start.
  if ! litestream restore -if-replica-exists -config /etc/litestream.yml "$DB"; then
    echo "[start.sh] FATAL: Litestream restore failed; refusing to start with an empty DB." >&2
    exit 1
  fi
fi
exec litestream replicate -config /etc/litestream.yml -exec "/app/bin/bundle exec puma -C /app/config/puma.rb --dir /app"
