"""Campus Lost & Found API.

Report lost/found items, mark them returned. Exposes Prometheus metrics on /metrics
and Kubernetes-style health endpoints on /api/health (readiness) and /api/live (liveness).
"""
import os
import time

import psycopg
from psycopg.rows import dict_row
from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import (CONTENT_TYPE_LATEST, Counter, Gauge, Histogram,
                               generate_latest)
from pydantic import BaseModel

APP_VERSION = os.getenv("APP_VERSION", "dev")
GIT_SHA = os.getenv("GIT_SHA", "local")

DB_DSN = (
    f"host={os.getenv('DB_HOST', 'localhost')} port={os.getenv('DB_PORT', '5432')} "
    f"dbname={os.getenv('DB_NAME', 'lostfound')} user={os.getenv('DB_USER', 'lostfound')} "
    f"password={os.getenv('DB_PASSWORD', 'lostfound')}"
)

app = FastAPI(title="Campus Lost & Found", version=APP_VERSION)

# ---- metrics -------------------------------------------------------------
HTTP_REQUESTS = Counter(
    "http_requests_total", "HTTP requests", ["method", "path", "status"])
HTTP_LATENCY = Histogram(
    "http_request_duration_seconds", "Request latency", ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5))
DB_UP = Gauge("lostfound_db_up", "1 if the last database check succeeded")
ITEMS_OPEN = Gauge("lostfound_items_open", "Open (not yet returned) items")


def _route_template(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    start = time.perf_counter()
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception:
        status = 500
        raise
    finally:
        path = _route_template(request)
        if path != "/metrics":
            HTTP_REQUESTS.labels(request.method, path, str(status)).inc()
            HTTP_LATENCY.labels(request.method, path).observe(time.perf_counter() - start)
    return response


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


# ---- models ---------------------------------------------------------------
class ItemIn(BaseModel):
    title: str
    location: str
    kind: str = "lost"          # lost | found


class ItemPatch(BaseModel):
    status: str                 # open | returned


def conn():
    return psycopg.connect(DB_DSN, row_factory=dict_row, connect_timeout=3)


@app.on_event("startup")
def init_db():
    if os.getenv("SKIP_DB_INIT") == "1":        # unit tests
        return
    # fail fast: a few short retries, then crash so the problem is visible in `kubectl logs`
    for attempt in range(1, int(os.getenv("DB_RETRIES", "10")) + 1):
        try:
            with conn() as c:
                c.execute("""
                    CREATE TABLE IF NOT EXISTS items (
                        id SERIAL PRIMARY KEY,
                        title TEXT NOT NULL,
                        location TEXT NOT NULL,
                        kind TEXT NOT NULL DEFAULT 'lost',
                        status TEXT NOT NULL DEFAULT 'open',
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )""")
            DB_UP.set(1)
            print(f"database ready on attempt {attempt}", flush=True)
            return
        except psycopg.OperationalError as e:
            DB_UP.set(0)
            print(f"database not ready (attempt {attempt}): {str(e).strip().splitlines()[0]}",
                  flush=True)
            time.sleep(2)
    raise RuntimeError("could not reach the database")


# ---- health ---------------------------------------------------------------
@app.get("/api/live")
def live():
    """Liveness: the process is up. Never touches the database."""
    return {"status": "alive", "version": APP_VERSION, "sha": GIT_SHA}


@app.get("/api/health")
def health():
    """Readiness: fails (503) when Postgres is unreachable so the Service stops routing here."""
    try:
        with conn() as c:
            c.execute("SELECT 1")
    except psycopg.OperationalError as e:
        DB_UP.set(0)
        raise HTTPException(503, f"database unreachable: {str(e).strip().splitlines()[0]}")
    DB_UP.set(1)
    return {"status": "ok", "db": "up", "version": APP_VERSION}


# ---- items ----------------------------------------------------------------
@app.get("/api/items")
def list_items():
    with conn() as c:
        rows = c.execute(
            "SELECT id, title, location, kind, status FROM items ORDER BY id").fetchall()
    ITEMS_OPEN.set(sum(1 for r in rows if r["status"] == "open"))
    return rows


@app.post("/api/items", status_code=201)
def create_item(item: ItemIn):
    if item.kind not in ("lost", "found"):
        raise HTTPException(422, "kind must be 'lost' or 'found'")
    if not item.title.strip() or not item.location.strip():
        raise HTTPException(422, "title and location are required")
    with conn() as c:
        return c.execute(
            "INSERT INTO items (title, location, kind) VALUES (%s, %s, %s) "
            "RETURNING id, title, location, kind, status",
            (item.title.strip(), item.location.strip(), item.kind)).fetchone()


@app.patch("/api/items/{item_id}")
def update_item(item_id: int, patch: ItemPatch):
    if patch.status not in ("open", "returned"):
        raise HTTPException(422, "status must be 'open' or 'returned'")
    with conn() as c:
        row = c.execute(
            "UPDATE items SET status = %s WHERE id = %s "
            "RETURNING id, title, location, kind, status",
            (patch.status, item_id)).fetchone()
    if not row:
        raise HTTPException(404, "item not found")
    return row


@app.delete("/api/items/{item_id}", status_code=204)
def delete_item(item_id: int):
    with conn() as c:
        if c.execute("DELETE FROM items WHERE id = %s", (item_id,)).rowcount == 0:
            raise HTTPException(404, "item not found")
