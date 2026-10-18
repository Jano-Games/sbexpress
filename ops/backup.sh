#!/bin/sh
set -eu
umask 077
# This container can reach only this compose project's local database.
mkdir -p /backups
while true; do
  if [ ! -f /backups/last-success ] || [ "$(($(date +%s) - $(cat /backups/last-success)))" -ge 86400 ]; then
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    target="/backups/mamun-local-$stamp.dump"
    if pg_dump --format=custom --no-owner --no-acl --file="$target.partial" && pg_restore --list "$target.partial" >/dev/null; then
      mv "$target.partial" "$target"
      date +%s > /backups/last-success
      printf '%s Database backup completed\n' "$stamp"
    else
      printf '%s Database backup FAILED; retrying in one hour\n' "$stamp" >&2
    fi
  fi
  sleep 3600
done
