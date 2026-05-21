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
        db.commit()
    app.teardown_appcontext(close_db)


def row_to_dict(row):
    return dict(row) if row else None
