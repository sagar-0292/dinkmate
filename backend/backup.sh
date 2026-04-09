#!/bin/bash
# ============================================================
# DinkMate — Automated Backup Script
# Backs up all Supabase data to JSON files
# Usage: bash backup.sh
# Cron: 0 2 * * * /path/to/backup.sh  (runs daily at 2am)
# ============================================================

set -e

# ── CONFIG ── (set these in your environment or .env file)
SUPABASE_URL="${SUPABASE_URL}"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_KEY}"   # Use service role key for backups
BACKUP_DIR="${BACKUP_DIR:-./backups}"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_PATH="$BACKUP_DIR/$DATE"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_KEY" ]; then
  echo "ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables"
  exit 1
fi

mkdir -p "$BACKUP_PATH"
echo "================================================"
echo " DinkMate Backup — $DATE"
echo " Saving to: $BACKUP_PATH"
echo "================================================"

# ── FUNCTION: dump a table to JSON ──
dump_table() {
  local TABLE=$1
  local FILENAME="$BACKUP_PATH/${TABLE}.json"
  echo "  Backing up: $TABLE..."
  curl -s \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: application/json" \
    "$SUPABASE_URL/rest/v1/$TABLE?select=*&limit=100000" \
    -o "$FILENAME"
  local COUNT=$(python3 -c "import json,sys; data=json.load(open('$FILENAME')); print(len(data))" 2>/dev/null || echo "?")
  echo "    ✓ $COUNT rows → $TABLE.json"
}

# ── BACK UP ALL TABLES ──
echo ""
echo "Backing up tables..."
dump_table "profiles"
dump_table "follows"
dump_table "posts"
dump_table "likes"
dump_table "comments"
dump_table "swipes"
dump_table "matches"
dump_table "messages"
dump_table "group_chats"
dump_table "group_messages"
dump_table "products"
dump_table "orders"
dump_table "saved_products"
dump_table "notifications"
dump_table "analytics_events"
dump_table "creator_earnings"
dump_table "user_badges"
dump_table "events"
dump_table "event_registrations"
dump_table "courts"

# ── METADATA FILE ──
cat > "$BACKUP_PATH/backup_meta.json" << EOF
{
  "backup_date": "$DATE",
  "supabase_url": "$SUPABASE_URL",
  "version": "1.0",
  "tables": [
    "profiles","follows","posts","likes","comments","swipes",
    "matches","messages","group_chats","group_messages","products",
    "orders","saved_products","notifications","analytics_events",
    "creator_earnings","user_badges","events","event_registrations","courts"
  ]
}
EOF

# ── COMPRESS BACKUP ──
echo ""
echo "Compressing backup..."
cd "$BACKUP_DIR"
tar -czf "${DATE}.tar.gz" "$DATE/"
rm -rf "$DATE/"
ARCHIVE_SIZE=$(du -sh "${DATE}.tar.gz" | cut -f1)
echo "  ✓ Archive: ${DATE}.tar.gz ($ARCHIVE_SIZE)"

# ── KEEP ONLY LAST 30 DAYS ──
echo ""
echo "Cleaning old backups (keeping 30 days)..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
BACKUP_COUNT=$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
echo "  ✓ $BACKUP_COUNT backups retained"

# ── OPTIONAL: UPLOAD TO S3/R2 ──
# Uncomment to auto-upload to Cloudflare R2 or AWS S3:
# aws s3 cp "$BACKUP_DIR/${DATE}.tar.gz" "s3://YOUR-BUCKET/dinkmate-backups/${DATE}.tar.gz"
# rclone copy "$BACKUP_DIR/${DATE}.tar.gz" r2:dinkmate-backups/

echo ""
echo "================================================"
echo " Backup complete! ✓"
echo " File: $BACKUP_DIR/${DATE}.tar.gz"
echo "================================================"
