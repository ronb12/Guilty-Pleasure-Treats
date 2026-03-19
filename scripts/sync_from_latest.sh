#!/usr/bin/env bash
#
# Sync the latest Guilty Pleasure Treats app source from ~/GuiltyPleasureTreats
# to ~/Desktop/Guilty Pleasure Treats so both locations have the same code
# (the home copy has the most features and latest edits).
#
# Usage: from repo root (Desktop project):
#   ./scripts/sync_from_latest.sh
#
# Optional: create a timestamped backup of Desktop's "Guilty Pleasure Treats"
# folder first by setting BACKUP=1:
#   BACKUP=1 ./scripts/sync_from_latest.sh
#

set -e
LATEST="/Users/ronellbradley/GuiltyPleasureTreats"
DEST="/Users/ronellbradley/Desktop/Guilty Pleasure Treats"
INNER="Guilty Pleasure Treats"   # folder containing .xcodeproj and app source

if [[ ! -d "$LATEST/$INNER" ]]; then
  echo "Error: Latest project not found at $LATEST/$INNER"
  exit 1
fi

if [[ -n "$BACKUP" && "$BACKUP" != "0" ]]; then
  BACKUP_DIR="$DEST/../Guilty-Pleasure-Treats-backup-$(date +%Y%m%d-%H%M%S)"
  echo "Backing up Desktop $INNER to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp -R "$DEST/$INNER" "$BACKUP_DIR/"
fi

echo "Syncing app source from $LATEST to Desktop..."
rsync -a --delete \
  --exclude='.git' \
  --exclude='build' \
  --exclude='DerivedData' \
  "$LATEST/$INNER/" "$DEST/$INNER/"

echo "Done. Desktop app source now matches latest (Home) copy."
