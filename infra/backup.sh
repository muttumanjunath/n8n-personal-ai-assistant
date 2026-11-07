#!/usr/bin/env bash
# Nightly backup of n8n data, chat memory and config. Keeps 7 days.
# Cron:  0 3 * * * /path/to/infra/backup.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p backups
docker compose exec -T postgres pg_dump -U n8n n8n_memory > backups/memory.sql
tar -czf "backups/n8n-$(date +%F).tar.gz" n8n_data docker-compose.yml .env searxng backups/memory.sql
find backups -name "n8n-*.tar.gz" -mtime +7 -delete
