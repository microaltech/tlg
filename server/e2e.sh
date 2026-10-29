#!/usr/bin/env bash
# Uji ujung ke ujung: server sungguhan + klien Godot (tools/online_check.tscn).
#   GODOT=/path/ke/godot server/e2e.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=${PORT:-18080}
DB=$(mktemp -d)/e2e.db
PORT=$PORT DB_PATH=$DB node server/server.js >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER' EXIT
for _ in $(seq 30); do curl -sf "localhost:$PORT/health" >/dev/null && break; sleep 0.2; done
TOKEN=$(curl -s -X POST "localhost:$PORT/v1/auth/device" -d '{"device_id":"pemain-lain-0000001","name":"Lawan"}' \
	| node -e 'process.stdin.on("data", d => console.log(JSON.parse(d).token))')
curl -s -X POST "localhost:$PORT/v1/profile" -H "Authorization: Bearer $TOKEN" \
	-d '{"alliance":"garuda","power":300,"name":"Lawan"}' >/dev/null
curl -s -X POST "localhost:$PORT/v1/chat" -H "Authorization: Bearer $TOKEN" -d '{"text":"Halo dari pemain lain"}' >/dev/null
"${GODOT:-godot}" --headless --path . res://tools/online_check.tscn -- "http://127.0.0.1:$PORT"
