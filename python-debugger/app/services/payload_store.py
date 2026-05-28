import json
import re
from hashlib import sha256
from pathlib import Path

from flask import current_app

from app.utils.json_utils import dumps, loads
from app.utils.time_utils import now_iso

INLINE_LIMIT_BYTES = 64 * 1024
PREVIEW_LIMIT_BYTES = 8 * 1024
SUMMARY_LIMIT_CHARS = 260
MAX_CHUNK_BYTES = 1024 * 1024
SAFE_SEGMENT_RE = re.compile(r"[^A-Za-z0-9_.-]+")


def payload_root():
    root = current_app.config.get("PAYLOAD_ROOT")
    if root:
        return Path(root)
    db_path = current_app.config.get("DATABASE", "data/debugger.sqlite3")
    if db_path == ":memory:":
        return Path("data") / "payloads"
    return Path(db_path).resolve().parent / "payloads"


def serialize_payload(value):
    if isinstance(value, str):
        return value, "text"
    return dumps(value), "json"


def payload_meta(value):
    text, content_format = serialize_payload(value)
    data = text.encode("utf-8")
    return {
        "content_text": text,
        "content_format": content_format,
        "summary": summarize_payload(value, text),
        "preview": data[:PREVIEW_LIMIT_BYTES].decode("utf-8", errors="replace"),
        "size": len(data),
        "hash": sha256(data).hexdigest(),
        "truncated": len(data) > PREVIEW_LIMIT_BYTES,
    }


def save_payload(db, session_id, call_id, payload_type, value, now=None):
    now = now or now_iso()
    meta = payload_meta(value)
    payload_id = f"payload-{sha256('|'.join([str(session_id), str(call_id), payload_type]).encode('utf-8')).hexdigest()[:24]}"
    storage_type = "inline" if meta["size"] <= INLINE_LIMIT_BYTES else "file"
    content_text = meta["content_text"] if storage_type == "inline" else None
    content_path = None
    if storage_type == "file":
        content_path = _payload_relative_path(session_id, call_id, payload_type, meta["content_format"])
        target = payload_root() / content_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(meta["content_text"], encoding="utf-8")
    db.execute(
        """INSERT INTO call_payloads
           (id, call_id, session_id, payload_type, storage_type, content_text, content_path,
            content_size, content_hash, content_encoding, content_format, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'utf-8', ?, ?)
           ON CONFLICT(call_id, payload_type) DO UPDATE SET
             session_id=excluded.session_id,
             storage_type=excluded.storage_type,
             content_text=excluded.content_text,
             content_path=excluded.content_path,
             content_size=excluded.content_size,
             content_hash=excluded.content_hash,
             content_encoding=excluded.content_encoding,
             content_format=excluded.content_format,
             created_at=excluded.created_at""",
        (
            payload_id,
            call_id,
            session_id,
            payload_type,
            storage_type,
            content_text,
            content_path.as_posix() if content_path else None,
            meta["size"],
            meta["hash"],
            meta["content_format"],
            now,
        ),
    )
    meta["payload_id"] = payload_id
    meta["storage_type"] = storage_type
    return meta


def payload_by_call(db, call_id, payload_type):
    return db.execute(
        """SELECT * FROM call_payloads
           WHERE call_id=? AND payload_type=?
           ORDER BY created_at DESC
           LIMIT 1""",
        (call_id, payload_type),
    ).fetchone()


def read_payload_text(row):
    if not row:
        return None
    if row["storage_type"] == "inline":
        return row["content_text"] or ""
    path = _resolve_payload_path(row["content_path"])
    if not path or not path.exists():
        return None
    return path.read_text(encoding=row["content_encoding"] or "utf-8", errors="replace")


def read_payload_value(row):
    text = read_payload_text(row)
    if text is None:
        return None
    if (row["content_format"] or "json") == "json":
        return loads(text, None)
    return text


def payload_chunk(db, call_id, payload_type, offset=0, limit=PREVIEW_LIMIT_BYTES):
    row = payload_by_call(db, call_id, payload_type)
    if not row:
        return None
    offset = max(0, int(offset or 0))
    limit = max(1, min(int(limit or PREVIEW_LIMIT_BYTES), MAX_CHUNK_BYTES))
    size = int(row["content_size"] or 0)
    if row["storage_type"] == "inline":
        text = row["content_text"] or ""
        data = text.encode("utf-8")
        chunk = data[offset:offset + limit]
    else:
        path = _resolve_payload_path(row["content_path"])
        if not path or not path.exists():
            return None
        with path.open("rb") as handle:
            handle.seek(offset)
            chunk = handle.read(limit)
    next_offset = min(size, offset + len(chunk))
    return {
        "callId": call_id,
        "type": payload_type,
        "offset": offset,
        "limit": limit,
        "size": size,
        "content": chunk.decode(row["content_encoding"] or "utf-8", errors="replace"),
        "nextOffset": next_offset,
        "hasMore": next_offset < size,
        "hash": row["content_hash"],
    }


def export_payload_target(db, call_id, payload_type):
    row = payload_by_call(db, call_id, payload_type)
    if not row:
        return None, None
    filename = f"{payload_type}.json" if (row["content_format"] or "json") == "json" else f"{payload_type}.txt"
    if row["storage_type"] == "file":
        path = _resolve_payload_path(row["content_path"])
        return row, path if path and path.exists() else None
    return row, filename


def search_payload(db, call_id, payload_type, query, limit=20):
    row = payload_by_call(db, call_id, payload_type)
    if not row:
        return None
    query = str(query or "")
    if not query:
        return {"callId": call_id, "type": payload_type, "q": query, "matches": []}
    text = read_payload_text(row) or ""
    matches = []
    start = 0
    while len(matches) < int(limit or 20):
        pos = text.find(query, start)
        if pos < 0:
            break
        before = max(0, pos - 80)
        after = min(len(text), pos + len(query) + 80)
        matches.append({"offset": len(text[:pos].encode("utf-8")), "preview": text[before:after]})
        start = pos + max(1, len(query))
    return {"callId": call_id, "type": payload_type, "q": query, "matches": matches}


def summarize_payload(value, serialized_text=None):
    if value is None:
        return "null"
    if isinstance(value, dict):
        parts = []
        for key in sorted(value.keys())[:8]:
            parts.append(f"{key}={_summary_value(value[key])}")
        if len(value) > 8:
            parts.append("...")
        text = ", ".join(parts) or "{}"
    elif isinstance(value, list):
        text = f"Array({len(value)})"
    else:
        text = str(value)
    if not text and serialized_text is not None:
        text = serialized_text.replace("\n", " ")
    text = " ".join(str(text).split())
    return text[:SUMMARY_LIMIT_CHARS - 3] + "..." if len(text) > SUMMARY_LIMIT_CHARS else text


def _summary_value(value):
    if isinstance(value, list):
        return f"Array({len(value)})"
    if isinstance(value, dict):
        return f"Object({len(value)})"
    text = str(value)
    return text[:37] + "..." if len(text) > 40 else text


def _payload_relative_path(session_id, call_id, payload_type, content_format):
    suffix = "json" if content_format == "json" else "txt"
    return Path(_safe_segment(session_id)) / _bucket(call_id) / _safe_segment(call_id) / f"{payload_type}.{suffix}"


def _safe_segment(value):
    text = str(value or "unknown").strip() or "unknown"
    return SAFE_SEGMENT_RE.sub("_", text)[:120]


def _bucket(call_id):
    return sha256(str(call_id).encode("utf-8")).hexdigest()[:2]


def _resolve_payload_path(content_path):
    if not content_path:
        return None
    path = Path(content_path)
    if path.is_absolute():
        return path
    return payload_root() / path
