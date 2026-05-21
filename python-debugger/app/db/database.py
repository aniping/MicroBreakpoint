import sqlite3
from pathlib import Path

from flask import current_app, g


def get_db():
    if "db" not in g:
        db_path = current_app.config["DATABASE"]
        if db_path != ":memory:":
            Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        g.db = sqlite3.connect(db_path, check_same_thread=False)
        g.db.row_factory = sqlite3.Row
    return g.db


def close_db(_=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db(app):
    with app.app_context():
        db = get_db()
        schema = Path(__file__).resolve().parents[1] / "models" / "schema.sql"
        db.executescript(schema.read_text(encoding="utf-8"))
        migrate_db(db)
        db.commit()
    app.teardown_appcontext(close_db)


def row_to_dict(row):
    return dict(row) if row else None


def migrate_db(db):
    ensure_column(db, "call_record", "interface_id", "TEXT")
    ensure_column(db, "call_record", "discovery_enabled", "INTEGER DEFAULT 1")
    ensure_column(db, "discovered_interface", "interface_key", "TEXT")
    ensure_column(db, "discovered_interface", "http_method", "TEXT")
    ensure_column(db, "discovered_interface", "request_uri", "TEXT")
    ensure_column(db, "discovered_interface", "query_signature", "TEXT")
    ensure_column(db, "discovered_interface", "body_signature", "TEXT")
    ensure_column(db, "discovered_interface", "content_type", "TEXT")


def ensure_column(db, table, column, definition):
    rows = db.execute(f"PRAGMA table_info({table})").fetchall()
    if column not in {row["name"] for row in rows}:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
