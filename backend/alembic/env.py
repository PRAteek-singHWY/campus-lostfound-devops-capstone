"""Alembic environment: the database URL comes from the same DB_* variables the app uses."""
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

DATABASE_URL = os.getenv("DATABASE_URL") or (
    "postgresql+psycopg://{u}:{p}@{h}:{port}/{db}".format(
        u=os.getenv("DB_USER", "lostfound"), p=os.getenv("DB_PASSWORD", "lostfound"),
        h=os.getenv("DB_HOST", "localhost"), port=os.getenv("DB_PORT", "5432"),
        db=os.getenv("DB_NAME", "lostfound")))

target_metadata = None   # migrations are written by hand; no ORM models to autogenerate from


def run_migrations_offline():
    context.configure(url=DATABASE_URL, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
