#!/bin/bash
# LernSpiel — Daily SQLite database backup
# Usage: Run manually or add to crontab:
#   crontab -e
#   0 2 * * * /path/to/Lernraum-Check/scripts/backup-db.sh
#
# Keeps the last 30 days of backups.

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DB_FILE="$PROJECT_DIR/lernspiel.sqlite"
BACKUP_DIR="$PROJECT_DIR/backups"
RETENTION_DAYS=30

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Check if database exists
if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database not found at $DB_FILE"
    exit 1
fi

# Create timestamped backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/lernspiel_${TIMESTAMP}.sqlite"

# Use SQLite's .backup command for a safe copy (handles WAL mode)
if command -v sqlite3 &> /dev/null; then
    sqlite3 "$DB_FILE" ".backup '$BACKUP_FILE'"
else
    # Fallback to file copy
    cp "$DB_FILE" "$BACKUP_FILE"
fi

echo "Backup created: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Remove backups older than RETENTION_DAYS
DELETED=$(find "$BACKUP_DIR" -name "lernspiel_*.sqlite" -mtime +$RETENTION_DAYS -delete -print | wc -l)
if [ "$DELETED" -gt 0 ]; then
    echo "Cleaned up $DELETED old backup(s)."
fi
