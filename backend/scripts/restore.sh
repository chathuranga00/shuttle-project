#!/usr/bin/env bash
# ==============================================================================
# Database Restore Script for Shuttle Management System
# ==============================================================================
# Usage: ./restore.sh /path/to/shuttle_backup_YYYYMMDD_HHMMSS.sql.gz
# ==============================================================================

set -eo pipefail

if [[ -z "$1" ]] || [[ ! -f "$1" ]]; then
  echo "Usage: $0 <path-to-gzipped-backup.sql.gz>" >&2
  exit 1
fi

BACKUP_FILE="$1"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-shuttle_db}"
DB_USERNAME="${DB_USERNAME:-root}"

if [[ -z "${DB_PASSWORD}" ]]; then
  echo "[-] ERROR: DB_PASSWORD environment variable is required." >&2
  exit 1
fi

echo "[!] WARNING: This will overwrite data in database '${DB_NAME}' on ${DB_HOST}:${DB_PORT}."
read -rp "Are you sure you want to proceed? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo "[-] Restore cancelled."
  exit 0
fi

echo "[+] Decompressing and importing backup into ${DB_NAME}..."
gunzip < "${BACKUP_FILE}" | mysql \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --user="${DB_USERNAME}" \
  --password="${DB_PASSWORD}" \
  --default-character-set=utf8mb4 \
  "${DB_NAME}"

echo "[+] Restore completed successfully at $(date)."
