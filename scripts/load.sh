#!/usr/bin/env bash
# Generate traffic (and some 404s) so dashboards and the HPA have something to show.
set -euo pipefail
BASE="${1:-http://localhost:3100}"; N="${2:-500}"
for i in $(seq 1 "$N"); do
  curl -s "$BASE/api/items" >/dev/null
  curl -s "$BASE/api/health" >/dev/null
  [ $((i % 10)) -eq 0 ] && curl -s -o /dev/null -X DELETE "$BASE/api/items/999999"
done
echo "sent $N rounds"
