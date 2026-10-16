"""Unit tests run against an in-memory fake of the psycopg connection: no Postgres needed."""
import os

os.environ["SKIP_DB_INIT"] = "1"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import main  # noqa: E402


class FakeCursor:
    def __init__(self, rows):
        self._rows = rows
        self.rowcount = len(rows)

    def fetchall(self):
        return self._rows

    def fetchone(self):
        return self._rows[0] if self._rows else None


class FakeDB:
    """Just enough SQL understanding for the queries in app.main."""

    def __init__(self):
        self.items = {}
        self.next_id = 1
        self.down = False

    # context-manager protocol like psycopg.Connection
    def __enter__(self):
        if self.down:
            import psycopg
            raise psycopg.OperationalError("connection refused")
        return self

    def __exit__(self, *exc):
        return False

    def execute(self, sql, params=()):
        s = " ".join(sql.split())
        if s.startswith("SELECT 1"):
            return FakeCursor([{"?column?": 1}])
        if s.startswith("SELECT id, title, location, kind, status FROM items WHERE"):
            (item_id,) = params
            return FakeCursor([self.items[item_id]] if item_id in self.items else [])
        if s.startswith("SELECT id, title, location, kind, status FROM items"):
            return FakeCursor([self.items[i] for i in sorted(self.items)])
        if s.startswith("UPDATE items SET title"):
            title, location, kind, item_id = params
            row = self.items.get(item_id)
            if row:
                row.update(title=title, location=location, kind=kind)
                return FakeCursor([row])
            return FakeCursor([])
        if s.startswith("INSERT INTO items"):
            title, location, kind = params
            row = {"id": self.next_id, "title": title, "location": location,
                   "kind": kind, "status": "open"}
            self.items[self.next_id] = row
            self.next_id += 1
            return FakeCursor([row])
        if s.startswith("UPDATE items SET status"):
            status, item_id = params
            row = self.items.get(item_id)
            if row:
                row["status"] = status
                return FakeCursor([row])
            return FakeCursor([])
        if s.startswith("DELETE FROM items"):
            (item_id,) = params
            return FakeCursor([self.items.pop(item_id)] if item_id in self.items else [])
        short = " ".join(sql.split())[:60]
        raise AssertionError(f"unexpected SQL: {short}")


@pytest.fixture
def db(monkeypatch):
    fake = FakeDB()
    monkeypatch.setattr(main, "conn", lambda: fake)
    return fake


@pytest.fixture
def client(db):
    with TestClient(main.app) as c:
        yield c
