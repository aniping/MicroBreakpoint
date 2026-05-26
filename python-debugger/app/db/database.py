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
    ensure_column(db, "debug_session", "status", "TEXT")
    ensure_column(db, "debug_session", "archive_id", "TEXT")
    ensure_column(db, "debug_session", "archive_name", "TEXT")
    ensure_column(db, "debug_session", "archive_remark", "TEXT")
    ensure_column(db, "debug_session", "imported_at", "TEXT")
    ensure_column(db, "call_record", "object_name", "TEXT")
    ensure_column(db, "call_record", "cmd_name", "TEXT")
    ensure_column(db, "call_record", "slot_id", "INTEGER")
    ensure_column(db, "call_record", "slot_key", "TEXT")
    ensure_column(db, "call_record", "raw_args_json", "TEXT")
    ensure_column(db, "call_record", "params_json", "TEXT")
    ensure_column(db, "call_record", "params_fingerprint", "TEXT")
    ensure_column(db, "call_record", "params_summary", "TEXT")
    ensure_column(db, "call_record", "breakpoint_name", "TEXT")
    ensure_column(db, "call_record", "interface_id", "TEXT")
    ensure_column(db, "call_record", "discovery_enabled", "INTEGER DEFAULT 1")
    ensure_column(db, "call_record", "interface_registered", "INTEGER DEFAULT 1")
    ensure_column(db, "call_record", "continued_at", "TEXT")
    ensure_column(db, "call_record", "finished_at", "TEXT")
    ensure_column(db, "discovered_interface", "object_name", "TEXT")
    ensure_column(db, "discovered_interface", "cmd_name", "TEXT")
    ensure_column(db, "discovered_interface", "slot_id", "INTEGER")
    ensure_column(db, "discovered_interface", "slot_key", "TEXT")
    ensure_column(db, "discovered_interface", "interface_key", "TEXT")
    ensure_column(db, "discovered_interface", "http_method", "TEXT")
    ensure_column(db, "discovered_interface", "request_uri", "TEXT")
    ensure_column(db, "discovered_interface", "query_signature", "TEXT")
    ensure_column(db, "discovered_interface", "body_signature", "TEXT")
    ensure_column(db, "discovered_interface", "content_type", "TEXT")
    ensure_column(db, "discovered_interface", "interface_alias", "TEXT")
    ensure_column(db, "discovered_interface", "params_schema_json", "TEXT")
    ensure_column(db, "discovered_interface", "latest_params_json", "TEXT")
    ensure_column(db, "discovered_interface", "latest_params_fingerprint", "TEXT")
    ensure_column(db, "discovered_interface", "params_sample_count", "INTEGER DEFAULT 0")
    ensure_column(db, "discovered_interface", "params_summary", "TEXT")
    ensure_column(db, "breakpoint", "scope", "TEXT")
    ensure_column(db, "breakpoint", "session_id", "TEXT")
    ensure_column(db, "breakpoint", "object_name", "TEXT")
    ensure_column(db, "breakpoint", "cmd_name", "TEXT")
    ensure_column(db, "breakpoint", "slot_id", "INTEGER")
    ensure_column(db, "breakpoint", "slot_key", "TEXT")
    ensure_column(db, "breakpoint", "match_mode", "TEXT")
    ensure_column(db, "breakpoint", "params_fingerprint", "TEXT")
    ensure_column(db, "breakpoint", "params_snapshot_json", "TEXT")
    ensure_column(db, "breakpoint", "conditions_json", "TEXT")
    ensure_column(db, "breakpoint", "hit_limit", "INTEGER")
    ensure_column(db, "breakpoint", "source_type", "TEXT")
    db.execute(
        """CREATE TABLE IF NOT EXISTS interface_param_sample (
          id TEXT PRIMARY KEY,
          interface_id TEXT,
          params_fingerprint TEXT,
          params_json TEXT,
          first_seen_at TEXT,
          last_seen_at TEXT,
          seen_count INTEGER,
          UNIQUE(interface_id, params_fingerprint)
        )"""
    )
    db.execute(
        """CREATE TABLE IF NOT EXISTS app_setting (
          key TEXT PRIMARY KEY,
          value TEXT,
          updated_at TEXT
        )"""
    )


def ensure_column(db, table, column, definition):
    rows = db.execute(f"PRAGMA table_info({table})").fetchall()
    if column not in {row["name"] for row in rows}:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
