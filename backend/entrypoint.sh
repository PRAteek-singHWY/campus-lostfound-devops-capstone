#!/bin/sh
# Wait for Postgres, apply Alembic migrations, then start the API.
set -e
: "${DB_HOST:=localhost}"; : "${DB_PORT:=5432}"
i=0
until python -c "import socket,sys; s=socket.create_connection(('$DB_HOST', $DB_PORT), 2); s.close()" 2>/dev/null; do
  i=$((i+1)); [ "$i" -ge "${DB_WAIT_SECONDS:-60}" ] && { echo "database $DB_HOST:$DB_PORT not reachable after ${i}s"; exit 3; }
  echo "waiting for database $DB_HOST:$DB_PORT ($i)"; sleep 1
done
alembic upgrade head
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers
