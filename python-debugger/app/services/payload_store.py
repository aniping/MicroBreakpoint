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
SEARCH_CHUNK_BYTES = 1024 * 1024
SEARCH_PREVIEW_CHARS = 100
PREVIEW_STRING_CHARS = 180
PREVIEW_COLLECTION_ITEMS = 6
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
    try:
        return dumps(value), "json"
    except TypeError:
        return str(value), "text"


def payload_meta(value):
    text, content_format = serialize_payload(value)
    data = text.encode("utf-8")
    truncated = len(data) > PREVIEW_LIMIT_BYTES
    return {
        "content_text": text,
        "content_format": content_format,
        "summary": summarize_payload(value, text),
        "preview": preview_payload(value, text, content_format, truncated, len(data)),
        "size": len(data),
        "hash": sha256(data).hexdigest(),
        "truncated": truncated,
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


def save_payload_file_copy(db, session_id, call_id, payload_type, source, content_format="json", content_encoding="utf-8", expected_size=None, expected_hash=None, now=None):
    now = now or now_iso()
    content_format = content_format or "json"
    content_encoding = content_encoding or "utf-8"
    payload_id = f"payload-{sha256('|'.join([str(session_id), str(call_id), payload_type]).encode('utf-8')).hexdigest()[:24]}"
    content_path = _payload_relative_path(session_id, call_id, payload_type, content_format)
    target = payload_root() / content_path
    target.parent.mkdir(parents=True, exist_ok=True)
    hasher = sha256()
    size = 0
    with target.open("wb") as handle:
        while True:
            chunk = source.read(MAX_CHUNK_BYTES)
            if not chunk:
                break
            if isinstance(chunk, str):
                chunk = chunk.encode(content_encoding, errors="replace")
            hasher.update(chunk)
            size += len(chunk)
            handle.write(chunk)
    content_hash = hasher.hexdigest()
    if expected_size is not None and int(expected_size or 0) != size:
        raise ValueError("payload size mismatch")
    if expected_hash and expected_hash != content_hash:
        raise ValueError("payload hash mismatch")
    db.execute(
        """INSERT INTO call_payloads
           (id, call_id, session_id, payload_type, storage_type, content_text, content_path,
            content_size, content_hash, content_encoding, content_format, created_at)
           VALUES (?, ?, ?, ?, 'file', NULL, ?, ?, ?, ?, ?, ?)
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
            content_path.as_posix(),
            size,
            content_hash,
            content_encoding,
            content_format,
            now,
        ),
    )
    return {"payload_id": payload_id, "storage_type": "file", "size": size, "hash": content_hash}


def payload_by_call(db, call_id, payload_type):
    return db.execute(
        """SELECT * FROM call_payloads
           WHERE call_id=? AND payload_type=?
           ORDER BY created_at DESC
           LIMIT 1""",
        (call_id, payload_type),
    ).fetchone()


def payload_by_id(db, payload_id):
    return db.execute(
        "SELECT * FROM call_payloads WHERE id=?",
        (payload_id,),
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
    return payload_chunk_from_row(row, offset, limit, call_id=call_id, payload_type=payload_type)


def payload_chunk_by_id(db, payload_id, offset=0, limit=PREVIEW_LIMIT_BYTES):
    row = payload_by_id(db, payload_id)
    return payload_chunk_from_row(row, offset, limit, payload_id=payload_id)


def payload_chunk_from_row(row, offset=0, limit=PREVIEW_LIMIT_BYTES, call_id=None, payload_type=None, payload_id=None):
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
        "success": True,
        "payloadId": payload_id or row["id"],
        "callId": call_id or row["call_id"],
        "type": payload_type or row["payload_type"],
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
    return export_payload_target_from_row(row)


def export_payload_by_id(db, payload_id):
    row = payload_by_id(db, payload_id)
    return export_payload_target_from_row(row)


def export_payload_target_from_row(row):
    if not row:
        return None, None
    payload_type = row["payload_type"] or "payload"
    filename = f"{payload_type}.json" if (row["content_format"] or "json") == "json" else f"{payload_type}.txt"
    if row["storage_type"] == "file":
        path = _resolve_payload_path(row["content_path"])
        return row, path if path and path.exists() else None
    return row, filename


def search_payload(db, call_id, payload_type, query, limit=20):
    row = payload_by_call(db, call_id, payload_type)
    return search_payload_from_row(row, query, limit, call_id=call_id, payload_type=payload_type)


def search_payload_by_id(db, payload_id, query, limit=20):
    row = payload_by_id(db, payload_id)
    return search_payload_from_row(row, query, limit, payload_id=payload_id)


def search_payload_from_row(row, query, limit=20, call_id=None, payload_type=None, payload_id=None):
    if not row:
        return None
    query = str(query or "")
    if not query:
        return {
            "success": True,
            "payloadId": payload_id or row["id"],
            "callId": call_id or row["call_id"],
            "type": payload_type or row["payload_type"],
            "q": query,
            "matches": [],
        }
    limit = max(1, int(limit or 20))
    if row["storage_type"] == "file":
        path = _resolve_payload_path(row["content_path"])
        if not path or not path.exists():
            return None
        matches = _search_file_payload(path, row["content_encoding"] or "utf-8", query, limit)
        return {
            "success": True,
            "payloadId": payload_id or row["id"],
            "callId": call_id or row["call_id"],
            "type": payload_type or row["payload_type"],
            "q": query,
            "matches": matches,
        }
    text = row["content_text"] or ""
    matches = []
    start = 0
    while len(matches) < limit:
        pos = text.find(query, start)
        if pos < 0:
            break
        before = max(0, pos - SEARCH_PREVIEW_CHARS)
        after = min(len(text), pos + len(query) + SEARCH_PREVIEW_CHARS)
        matches.append({"offset": len(text[:pos].encode("utf-8")), "preview": text[before:after]})
        start = pos + max(1, len(query))
    return {
        "success": True,
        "payloadId": payload_id or row["id"],
        "callId": call_id or row["call_id"],
        "type": payload_type or row["payload_type"],
        "q": query,
        "matches": matches,
    }


def _search_file_payload(path, encoding, query, limit):
    query_bytes = query.encode(encoding, errors="replace")
    if not query_bytes:
        return []
    matches = []
    overlap_size = max(0, len(query_bytes) - 1)
    previous = b""
    offset = 0
    last_match = -1
    with path.open("rb") as handle:
        while len(matches) < limit:
            chunk = handle.read(SEARCH_CHUNK_BYTES)
            if not chunk:
                break
            window = previous + chunk
            window_base = offset - len(previous)
            start = 0
            while len(matches) < limit:
                pos = window.find(query_bytes, start)
                if pos < 0:
                    break
                absolute = window_base + pos
                if absolute > last_match:
                    matches.append({
                        "offset": absolute,
                        "preview": _file_payload_preview(path, encoding, absolute, len(query_bytes)),
                    })
                    last_match = absolute
                start = pos + max(1, len(query_bytes))
            previous = window[-overlap_size:] if overlap_size else b""
            offset += len(chunk)
    return matches


def _file_payload_preview(path, encoding, offset, query_size):
    before_bytes = SEARCH_PREVIEW_CHARS * 4
    after_bytes = (SEARCH_PREVIEW_CHARS * 4) + query_size
    start = max(0, offset - before_bytes)
    with path.open("rb") as handle:
        handle.seek(start)
        data = handle.read((offset - start) + after_bytes)
    prefix_size = offset - start
    prefix = data[:prefix_size].decode(encoding, errors="replace")
    match = data[prefix_size:prefix_size + query_size].decode(encoding, errors="replace")
    suffix = data[prefix_size + query_size:].decode(encoding, errors="replace")
    return prefix[-SEARCH_PREVIEW_CHARS:] + match + suffix[:SEARCH_PREVIEW_CHARS]


def preview_payload(value, serialized_text, content_format, truncated, content_size):
    if not truncated:
        return serialized_text
    if content_format != "json":
        return serialized_text.encode("utf-8")[:PREVIEW_LIMIT_BYTES].decode("utf-8", errors="replace")
    return json_preview_text(value, content_size)


def json_preview_text(value, content_size):
    for string_limit in (PREVIEW_STRING_CHARS, 120, 60):
        for item_limit in (PREVIEW_COLLECTION_ITEMS, 4, 2):
            preview = preview_json_value(value, string_limit, item_limit)
            text = dumps(preview)
            if len(text.encode("utf-8")) <= PREVIEW_LIMIT_BYTES:
                return text
    return dumps({
        "__preview__": "payload truncated",
        "contentSize": content_size,
        "message": "Full payload is available via load more or export.",
    })


def preview_json_value(value, string_limit, item_limit, depth=0):
    if depth >= 6:
        return preview_marker(value)
    if isinstance(value, str):
        if len(value) <= string_limit:
            return value
        return value[:string_limit] + "…"
    if isinstance(value, list):
        items = [preview_json_value(item, string_limit, item_limit, depth + 1) for item in value[:item_limit]]
        if len(value) > item_limit:
            items.append({"__preview__": "items truncated", "omittedItems": len(value) - item_limit})
        return items
    if isinstance(value, dict):
        result = {}
        keys = list(value.keys())
        for index, key in enumerate(keys[:item_limit]):
            preview_key = preview_json_key(key, string_limit)
            if preview_key in result:
                preview_key = f"{preview_key} #{index + 1}"
            result[preview_key] = preview_json_value(value[key], string_limit, item_limit, depth + 1)
        if len(keys) > item_limit:
            result["__preview__"] = {
                "keyCount": len(keys),
                "shownKeys": item_limit,
                "omittedKeys": len(keys) - item_limit,
            }
        return result
    return value


def preview_json_key(key, string_limit):
    text = str(key)
    limit = max(24, min(string_limit, 120))
    if len(text) <= limit:
        return text
    return text[:limit] + f"... [key truncated {len(text) - limit} chars]"


def preview_marker(value):
    if isinstance(value, dict):
        return {"__preview__": "object truncated", "keyCount": len(value)}
    if isinstance(value, list):
        return {"__preview__": "array truncated", "itemCount": len(value)}
    if isinstance(value, str):
        return value[:80] + ("..." if len(value) > 80 else "")
    return value


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
