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
    ensure_column(db, "debug_session", "display_name", "TEXT")
    ensure_column(db, "debug_session", "import_file_name", "TEXT")
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
    ensure_column(db, "call_record", "params_preview", "TEXT")
    ensure_column(db, "call_record", "params_size", "INTEGER DEFAULT 0")
    ensure_column(db, "call_record", "params_hash", "TEXT")
    ensure_column(db, "call_record", "params_truncated", "INTEGER DEFAULT 0")
    ensure_column(db, "call_record", "params_payload_id", "TEXT")
    ensure_column(db, "call_record", "result_summary", "TEXT")
    ensure_column(db, "call_record", "result_preview", "TEXT")
    ensure_column(db, "call_record", "result_size", "INTEGER DEFAULT 0")
    ensure_column(db, "call_record", "result_hash", "TEXT")
    ensure_column(db, "call_record", "result_truncated", "INTEGER DEFAULT 0")
    ensure_column(db, "call_record", "result_payload_id", "TEXT")
    ensure_column(db, "call_record", "payload_status", "TEXT DEFAULT 'ready'")
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
    ensure_column(db, "breakpoint", "params_hash", "TEXT")
    ensure_column(db, "breakpoint", "params_summary", "TEXT")
    ensure_column(db, "breakpoint", "params_payload_id", "TEXT")
    ensure_column(db, "breakpoint", "params_snapshot_json", "TEXT")
    ensure_column(db, "breakpoint", "condition_fields_json", "TEXT")
    ensure_column(db, "breakpoint", "conditions_json", "TEXT")
    ensure_column(db, "breakpoint", "hit_limit", "INTEGER")
    ensure_column(db, "breakpoint", "source_type", "TEXT")
    ensure_interface_param_sample_schema(db)
    ensure_call_payloads_schema(db)
    ensure_payload_indexes(db)
    ensure_interface_unique_index(db)
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


def ensure_interface_param_sample_schema(db):
    db.execute(
        """CREATE TABLE IF NOT EXISTS interface_param_sample (
          id TEXT PRIMARY KEY,
          interface_id TEXT,
          call_id TEXT,
          object_name TEXT,
          cmd_name TEXT,
          slot_id INTEGER,
          slot_key TEXT,
          args_json TEXT,
          params_fingerprint TEXT,
          params_hash TEXT,
          params_summary TEXT,
          params_preview TEXT,
          params_truncated INTEGER DEFAULT 0,
          params_size INTEGER DEFAULT 0,
          params_payload_id TEXT,
          params_json TEXT,
          result_json TEXT,
          result_summary TEXT,
          result_size INTEGER DEFAULT 0,
          result_payload_id TEXT,
          success INTEGER,
          cost_ms INTEGER,
          first_seen_at TEXT,
          last_seen_at TEXT,
          created_at TEXT,
          updated_at TEXT,
          seen_count INTEGER,
          UNIQUE(interface_id, slot_key, params_fingerprint)
        )"""
    )
    columns = {row["name"] for row in db.execute("PRAGMA table_info(interface_param_sample)").fetchall()}
    required = {
        "id", "interface_id", "call_id", "object_name", "cmd_name", "slot_id", "slot_key",
        "args_json", "params_fingerprint", "params_hash", "params_summary", "params_size",
        "params_preview", "params_truncated", "params_payload_id", "params_json", "result_json",
        "result_summary", "result_size", "result_payload_id", "success", "cost_ms",
        "first_seen_at", "last_seen_at", "created_at", "updated_at", "seen_count",
    }
    has_new_unique = any(
        index["unique"]
        and [col["name"] for col in db.execute(f"PRAGMA index_info({index['name']})").fetchall()]
        == ["interface_id", "slot_key", "params_fingerprint"]
        for index in db.execute("PRAGMA index_list(interface_param_sample)").fetchall()
    )
    if required.issubset(columns) and has_new_unique:
        return

    db.execute("ALTER TABLE interface_param_sample RENAME TO interface_param_sample_old")
    db.execute(
        """CREATE TABLE interface_param_sample (
          id TEXT PRIMARY KEY,
          interface_id TEXT,
          call_id TEXT,
          object_name TEXT,
          cmd_name TEXT,
          slot_id INTEGER,
          slot_key TEXT,
          args_json TEXT,
          params_fingerprint TEXT,
          params_hash TEXT,
          params_summary TEXT,
          params_preview TEXT,
          params_truncated INTEGER DEFAULT 0,
          params_size INTEGER DEFAULT 0,
          params_payload_id TEXT,
          params_json TEXT,
          result_json TEXT,
          result_summary TEXT,
          result_size INTEGER DEFAULT 0,
          result_payload_id TEXT,
          success INTEGER,
          cost_ms INTEGER,
          first_seen_at TEXT,
          last_seen_at TEXT,
          created_at TEXT,
          updated_at TEXT,
          seen_count INTEGER,
          UNIQUE(interface_id, slot_key, params_fingerprint)
        )"""
    )
    old_columns = {row["name"] for row in db.execute("PRAGMA table_info(interface_param_sample_old)").fetchall()}
    select_value = lambda column, fallback: column if column in old_columns else fallback
    db.execute(
        f"""INSERT OR IGNORE INTO interface_param_sample
           (id, interface_id, call_id, object_name, cmd_name, slot_id, slot_key, args_json,
            params_fingerprint, params_hash, params_summary, params_preview, params_truncated,
            params_size, params_payload_id,
            params_json, result_json, result_summary, result_size, result_payload_id, success, cost_ms,
            first_seen_at, last_seen_at, created_at, updated_at, seen_count)
           SELECT id, interface_id,
                  {select_value('call_id', 'NULL')},
                  {select_value('object_name', 'NULL')},
                  {select_value('cmd_name', 'NULL')},
                  {select_value('slot_id', 'NULL')},
                  COALESCE({select_value('slot_key', 'NULL')}, '__NULL__'),
                  {select_value('args_json', 'NULL')},
                  params_fingerprint,
                  COALESCE({select_value('params_hash', 'NULL')}, params_fingerprint),
                  {select_value('params_summary', 'NULL')},
                  {select_value('params_preview', 'NULL')},
                  COALESCE({select_value('params_truncated', 'NULL')}, 0),
                  COALESCE({select_value('params_size', 'NULL')}, 0),
                  {select_value('params_payload_id', 'NULL')},
                  params_json,
                  {select_value('result_json', 'NULL')},
                  {select_value('result_summary', 'NULL')},
                  COALESCE({select_value('result_size', 'NULL')}, 0),
                  {select_value('result_payload_id', 'NULL')},
                  {select_value('success', 'NULL')},
                  {select_value('cost_ms', 'NULL')},
                  first_seen_at, last_seen_at,
                  COALESCE({select_value('created_at', 'NULL')}, first_seen_at),
                  COALESCE({select_value('updated_at', 'NULL')}, last_seen_at),
                  seen_count
           FROM interface_param_sample_old"""
    )
    db.execute("DROP TABLE interface_param_sample_old")


def ensure_call_payloads_schema(db):
    db.execute(
        """CREATE TABLE IF NOT EXISTS call_payloads (
          id TEXT PRIMARY KEY,
          call_id TEXT,
          session_id TEXT,
          payload_type TEXT,
          storage_type TEXT,
          content_text TEXT,
          content_path TEXT,
          content_size INTEGER,
          content_hash TEXT,
          content_encoding TEXT,
          content_format TEXT,
          created_at TEXT,
          UNIQUE(call_id, payload_type)
        )"""
    )


def ensure_payload_indexes(db):
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_calls_session_object_time
           ON call_record(session_id, object_name, created_at DESC)"""
    )
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_calls_session_object_cmd
           ON call_record(session_id, object_name, cmd_name)"""
    )
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_calls_session_status
           ON call_record(session_id, status)"""
    )
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_calls_session_hit
           ON call_record(session_id, breakpoint_id)"""
    )
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_payload_call_type
           ON call_payloads(call_id, payload_type)"""
    )
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_samples_interface_hash
           ON interface_param_sample(interface_id, slot_key, params_hash)"""
    )
    db.execute(
        """CREATE INDEX IF NOT EXISTS idx_breakpoints_session_object_cmd
           ON breakpoint(session_id, object_name, cmd_name, enabled)"""
    )


def ensure_interface_unique_index(db):
    duplicates = db.execute(
        """SELECT 1
           FROM discovered_interface
           GROUP BY session_id, object_name, cmd_name
           HAVING COUNT(*) > 1
           LIMIT 1"""
    ).fetchone()
    if duplicates:
        return
    db.execute(
        """CREATE UNIQUE INDEX IF NOT EXISTS idx_discovered_interface_session_object_cmd
           ON discovered_interface(session_id, object_name, cmd_name)"""
    )
