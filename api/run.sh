#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && set -a && . ./.env && set +a
BIN=.venv/bin/uvicorn; [ -x "$BIN" ] || BIN=uvicorn
exec "$BIN" app.main:app --host "${HOST:-0.0.0.0}" --port "${PORT:-8002}"
