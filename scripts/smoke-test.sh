#!/usr/bin/env bash
# End-to-end API check through the frontend (nginx -> backend -> postgres).
# Usage: ./scripts/smoke-test.sh http://localhost:3100
set -euo pipefail
BASE="${1:-http://localhost:3100}"
J='Content-Type: application/json'
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; exit 1; }

echo "smoke test against $BASE"
for i in $(seq 1 30); do curl -fs "$BASE/api/health" >/dev/null && break; sleep 2; done

curl -fs "$BASE/healthz" | grep -q ok && pass "frontend /healthz" || fail "frontend /healthz"
curl -fs "$BASE/" | grep -qi "<div id=\"root\"" && pass "React index served" || fail "React index"
curl -fs "$BASE/api/health" | grep -q '"db":"up"' && pass "backend readiness, db up" || fail "readiness"
curl -fs "$BASE/api/live" | grep -q alive && pass "backend liveness" || fail "liveness"

ID=$(curl -fs -X POST "$BASE/api/items" -H "$J" \
     -d '{"title":"Blue water bottle","location":"Library 2nd floor","kind":"lost"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
pass "POST /api/items -> id $ID"
curl -fs "$BASE/api/items" | grep -q "Blue water bottle" && pass "GET /api/items lists it" || fail "list"
curl -fs -X PATCH "$BASE/api/items/$ID" -H "$J" -d '{"status":"returned"}' | grep -q returned && pass "PATCH -> returned" || fail "patch"
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/items/$ID"); [ "$code" = 204 ] && pass "DELETE -> 204" || fail "delete $code"
code=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/items/$ID"); [ "$code" = 404 ] && pass "second DELETE -> 404" || fail "404 $code"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/items" -H "$J" -d '{"title":"x","location":"y","kind":"stolen"}'); [ "$code" = 422 ] && pass "invalid kind -> 422" || fail "422 $code"
curl -fs "$BASE/api/metrics" >/dev/null 2>&1 || true
echo "all smoke tests passed"
