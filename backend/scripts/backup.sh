#!/usr/bin/env bash
# ==============================================================================
# Automated Database Backup Script for Shuttle Management System
# ==============================================================================
# Requirements: mysqldump, gzip
# Cron Example (Daily at 02:00 AM UTC):
# 0 2 * * * /opt/shuttle/backend/scripts/backup.sh >> /var/log/shuttle_backup.log 2>&1
# ==============================================================================

set -eo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/shuttle}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
DATE="$(date +'%Y%m%d_%H%M%S')"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-shuttle_db}"
DB_USERNAME="${DB_USERNAME:-root}"
# Ensure password is supplied via env or .env file
if [[ -z "${DB_PASSWORD}" ]]; then
  echo "[-] ERROR: DB_PASSWORD environment variable is required." >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

BACKUP_FILE="${BACKUP_DIR}/shuttle_backup_${DATE}.sql.gz"

echo "[+] Starting MySQL backup for ${DB_NAME} at $(date)..."

# Perform consistent online backup using InnoDB single-transaction snapshot
mysqldump \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --user="${DB_USERNAME}" \
  --password="${DB_PASSWORD}" \
  --single-transaction \
  --quick \
  --routines \
  --triggers \
  --hex-blob \
  --default-character-set=utf8mb4 \
  "${DB_NAME}" | gzip -9 > "${BACKUP_FILE}"

echo "[+] Backup successfully created: ${BACKUP_FILE} ($(du -h "${BACKUP_FILE}" | cut -f1))"

# Prune archives older than retention threshold
echo "[+] Pruning backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -type f -name "shuttle_backup_*.sql.gz" -mtime "+${RETENTION_DAYS}" -exec rm -f {} +
echo "[+] Backup routine complete."
