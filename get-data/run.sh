#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "=== Starting IronLog Exercise AI Cleaner ==="
python3 clean_catalog.py --workers 8 "$@"
