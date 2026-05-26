import json
import uuid
from hashlib import sha256

from app.db.database import get_db, row_to_dict
from app.services.wait_manager import wait_manager
from app.utils.json_utils import dumps, loads
from app.utils.time_utils import now_iso

UNCATEGORIZED_OBJECT = "未分类"
UNKNOWN_COMMAND = "未知命令"
NULL_SLOT_KEY = "__NULL__"
MBREC_FORMAT = "MicroBreakpoint Session Archive"
MBREC_VERSION = 1
INTERFACE_LOCK_SETTING = "interface_locked"

STATE = {"debugging": False, "mode": "idle", "sessionId": None}


def create_session(payload):
    stop_debug()
    session_id = f"session-{uuid.uuid4().hex[:10]}"
    now = now_iso()
    STATE.update(debugging=False, mode="idle", sessionId=session_id)
    db = get_db()
    db.execute(
        """INSERT INTO debug_session
        (id, mode, status, service_name, operator, start_time, recording, debugging, remark, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            session_id,
            "idle",
            "idle",
            payload.get("serviceName", "instrument-service-demo"),
            payload.get("operator", "developer"),
            now,
            0,
            0,
            payload.get("remark", ""),
            now,
            now,
        ),
    )
    db.commit()
    return state_response(success=True, sessionId=session_id)


def select_session(session_id):
    stop_debug()
    row = get_db().execute("SELECT id FROM debug_session WHERE id=?", (session_id,)).fetchone()
    if not row:
        return {"success": False, "message": "session not found"}
    STATE.update(debugging=False, mode="idle", sessionId=session_id)
    return state_response(success=True, sessionId=session_id)


def start_debug(payload=None):
    if not STATE["sessionId"]:
        create_session(payload or {})
    now = now_iso()
    STATE.update(debugging=True, mode="debug")
    db = get_db()
    db.execute(
        "UPDATE debug_session SET mode='debug', status='debugging', recording=0, debugging=1, end_time=NULL, updated_at=? WHERE id=?",
        (now, STATE["sessionId"]),
    )
    db.commit()
    return state_response(success=True)


def stop_debug():
    released = wait_manager.continue_all()
    if STATE["sessionId"]:
        now = now_iso()
        db = get_db()
        db.execute(
            "UPDATE call_record SET status='continued', continued_at=?, updated_at=? WHERE session_id=? AND status='paused'",
            (now, now, STATE["sessionId"]),
        )
        db.execute(
            "UPDATE debug_session SET mode='idle', status='idle', end_time=?, recording=0, debugging=0, updated_at=? WHERE id=?",
            (now, now, STATE["sessionId"]),
        )
        db.commit()
    STATE.update(debugging=False, mode="idle")
    return released


def reset_debug():
    released = wait_manager.continue_all()
    if STATE["sessionId"]:
        now = now_iso()
        db = get_db()
        db.execute(
            "UPDATE call_record SET status='continued', continued_at=?, updated_at=? WHERE session_id=? AND status='paused'",
            (now, now, STATE["sessionId"]),
        )
        db.commit()
    return state_response(success=True, releasedCount=released)


def clear_current_session():
    if STATE["debugging"]:
        return {"success": False, "message": "请先停止调试"}
    if not STATE["sessionId"]:
        return {"success": False, "message": "请先新建或选择 Session"}
    db = get_db()
    session_id = STATE["sessionId"]
    counts = {
        "calls": db.execute("SELECT COUNT(*) FROM call_record WHERE session_id=?", (session_id,)).fetchone()[0],
        "interfaces": db.execute("SELECT COUNT(*) FROM discovered_interface WHERE session_id=?", (session_id,)).fetchone()[0],
        "samples": db.execute(
            """SELECT COUNT(*) FROM interface_param_sample
               WHERE interface_id IN (SELECT id FROM discovered_interface WHERE session_id=?)""",
            (session_id,),
        ).fetchone()[0],
    }
    db.execute(
        """DELETE FROM interface_param_sample
           WHERE interface_id IN (SELECT id FROM discovered_interface WHERE session_id=?)""",
        (session_id,),
    )
    db.execute("DELETE FROM call_record WHERE session_id=?", (session_id,))
    db.execute("DELETE FROM discovered_interface WHERE session_id=?", (session_id,))
    db.commit()
    return state_response(success=True, deletedCount=counts)


def delete_session(session_id):
    if STATE["debugging"]:
        return {"success": False, "message": "请先停止调试"}
    db = get_db()
    row = db.execute("SELECT id FROM debug_session WHERE id=?", (session_id,)).fetchone()
    if not row:
        return {"success": False, "message": "session not found"}
    counts = {
        "calls": db.execute("SELECT COUNT(*) FROM call_record WHERE session_id=?", (session_id,)).fetchone()[0],
        "interfaces": db.execute("SELECT COUNT(*) FROM discovered_interface WHERE session_id=?", (session_id,)).fetchone()[0],
        "breakpoints": db.execute("SELECT COUNT(*) FROM breakpoint WHERE session_id=?", (session_id,)).fetchone()[0],
    }
    db.execute(
        """DELETE FROM interface_param_sample
           WHERE interface_id IN (SELECT id FROM discovered_interface WHERE session_id=?)""",
        (session_id,),
    )
    db.execute("DELETE FROM breakpoint WHERE session_id=?", (session_id,))
    db.execute("DELETE FROM call_record WHERE session_id=?", (session_id,))
    db.execute("DELETE FROM discovered_interface WHERE session_id=?", (session_id,))
    db.execute("DELETE FROM debug_session WHERE id=?", (session_id,))
    db.commit()
    if STATE["sessionId"] == session_id:
        STATE.update(debugging=False, mode="idle", sessionId=None)
    return state_response(success=True, deletedSessionId=session_id, deletedCount=counts)


def clear_sessions():
    if STATE["debugging"]:
        return {"success": False, "message": "请先停止调试"}
    db = get_db()
    counts = {
        "sessions": db.execute("SELECT COUNT(*) FROM debug_session").fetchone()[0],
        "calls": db.execute("SELECT COUNT(*) FROM call_record").fetchone()[0],
        "interfaces": db.execute("SELECT COUNT(*) FROM discovered_interface").fetchone()[0],
        "breakpoints": db.execute("SELECT COUNT(*) FROM breakpoint").fetchone()[0],
        "samples": db.execute("SELECT COUNT(*) FROM interface_param_sample").fetchone()[0],
    }
    db.execute("DELETE FROM interface_param_sample")
    db.execute("DELETE FROM breakpoint")
    db.execute("DELETE FROM call_record")
    db.execute("DELETE FROM discovered_interface")
    db.execute("DELETE FROM debug_session")
    db.commit()
    STATE.update(debugging=False, mode="idle", sessionId=None)
    return state_response(success=True, deletedCount=counts)


def state_response(**extra):
    db = get_db()
    session_id = STATE["sessionId"]
    if session_id:
        call_count = db.execute("SELECT COUNT(*) FROM call_record WHERE session_id=?", (session_id,)).fetchone()[0]
        interface_count = db.execute("SELECT COUNT(*) FROM discovered_interface WHERE session_id=?", (session_id,)).fetchone()[0]
        paused_count = db.execute(
            "SELECT COUNT(*) FROM call_record WHERE session_id=? AND status='paused'",
            (session_id,),
        ).fetchone()[0]
        running_count = db.execute(
            "SELECT COUNT(*) FROM call_record WHERE session_id=? AND status IN ('running','continued')",
            (session_id,),
        ).fetchone()[0]
        exception_count = db.execute(
            "SELECT COUNT(*) FROM call_record WHERE session_id=? AND status='exception'",
            (session_id,),
        ).fetchone()[0]
        last_report = db.execute(
            "SELECT MAX(updated_at) FROM call_record WHERE session_id=?",
            (session_id,),
        ).fetchone()[0]
    else:
        call_count = interface_count = paused_count = running_count = exception_count = 0
        last_report = None
    state = _state_name(paused_count)
    data = {
        "success": True,
        "state": state,
        "debugging": STATE["debugging"],
        "recording": STATE["debugging"],
        "mode": STATE["mode"],
        "hasSession": session_id is not None,
        "sessionId": session_id,
        "currentSessionId": session_id,
        "callCount": call_count,
        "interfaceCount": interface_count,
        "discoveredInterfaceCount": interface_count,
        "breakpointCount": breakpoint_count(db, session_id),
        "pausedCount": paused_count,
        "runningCount": running_count,
        "exceptionCount": exception_count,
        "lastReportTime": last_report,
        "interfaceLocked": interface_locked(),
    }
    data.update(extra)
    return data


def _state_name(paused_count):
    if not STATE["sessionId"]:
        return "NO_SESSION"
    if not STATE["debugging"]:
        return "SESSION_IDLE"
    if paused_count > 0:
        return "DEBUGGING_PAUSED"
    return "DEBUGGING"


def breakpoint_count(db, session_id):
    if not session_id:
        return 0
    return db.execute("SELECT COUNT(*) FROM breakpoint WHERE session_id=?", (session_id,)).fetchone()[0]


def interface_locked():
    row = get_db().execute("SELECT value FROM app_setting WHERE key=?", (INTERFACE_LOCK_SETTING,)).fetchone()
    return bool(row and row["value"] == "1")


def set_interface_locked(locked):
    now = now_iso()
    value = "1" if locked else "0"
    get_db().execute(
        """INSERT INTO app_setting (key, value, updated_at)
           VALUES (?, ?, ?)
           ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at""",
        (INTERFACE_LOCK_SETTING, value, now),
    )
    get_db().commit()
    return state_response(success=True, interfaceLocked=(value == "1"))


def before_call(payload):
    if not STATE["debugging"] or not STATE["sessionId"]:
        return {"success": True, "callIndex": 0, "action": "continue"}

    db = get_db()
    now = now_iso()
    session_id = STATE["sessionId"]
    call_data = call_business_data(payload)
    interface_id, interface_registered, discovery_enabled = resolve_interface_for_call(call_data, session_id, now)
    call_index = db.execute("SELECT COUNT(*) FROM call_record WHERE session_id=?", (session_id,)).fetchone()[0] + 1
    db.execute(
        """INSERT OR REPLACE INTO call_record
        (call_id, session_id, call_index, object_name, cmd_name, slot_id, slot_key,
         service_name, class_name, method_name, display_name, description, thread_name,
         args_json, raw_args_json, parameter_meta_json, params_json, params_fingerprint, params_summary,
         status, interface_id, discovery_enabled, interface_registered, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'running', ?, ?, ?, ?, ?)""",
        (
            payload["callId"],
            session_id,
            call_index,
            call_data["object_name"],
            call_data["cmd_name"],
            call_data["slot_id"],
            call_data["slot_key"],
            payload.get("serviceName"),
            payload.get("className"),
            payload.get("methodName"),
            payload.get("displayName"),
            call_data["description"],
            payload.get("threadName"),
            dumps(call_data["raw_args"]),
            dumps(call_data["raw_args"]),
            dumps(payload.get("parameterMeta", [])),
            dumps(call_data["params"]),
            call_data["params_fingerprint"],
            call_data["params_summary"],
            interface_id,
            discovery_enabled,
            interface_registered,
            now,
            now,
        ),
    )
    matched = match_breakpoint(call_data, session_id)
    if matched:
        wait_manager.create(payload["callId"])
        db.execute(
            """UPDATE call_record
               SET status='paused', breakpoint_id=?, breakpoint_name=?, updated_at=?
               WHERE call_id=?""",
            (matched["id"], matched["name"], now, payload["callId"]),
        )
        _apply_breakpoint_hit(db, matched, now)
        db.commit()
        return {
            "success": True,
            "callIndex": call_index,
            "action": "pause",
            "reason": "matched breakpoint",
            "waitTimeoutMs": 300000,
            "breakpointId": matched["id"],
            "breakpointName": matched["name"],
            "interfaceId": interface_id,
        }
    db.commit()
    return {"success": True, "callIndex": call_index, "action": "continue", "interfaceId": interface_id}


def after_call(payload):
    db = get_db()
    now = now_iso()
    row = db.execute("SELECT * FROM call_record WHERE call_id=?", (payload.get("callId"),)).fetchone()
    if not row:
        return {"success": True, "ignored": True}
    status = "finished" if payload.get("success") else "exception"
    db.execute(
        """UPDATE call_record SET result_json=?, success=?, exception_type=?, exception_message=?,
           cost_ms=?, status=?, finished_at=?, updated_at=? WHERE call_id=?""",
        (
            dumps(payload.get("result")),
            1 if payload.get("success") else 0,
            payload.get("exceptionType"),
            payload.get("exceptionMessage"),
            payload.get("costMs"),
            status,
            now,
            now,
            payload.get("callId"),
        ),
    )
    if row["discovery_enabled"] and row["interface_id"]:
        update_interface_stats(row, payload, now)
    db.commit()
    return {"success": True}


def call_business_data(payload):
    raw_args = payload.get("rawArgs")
    if raw_args is None:
        raw_args = payload.get("args", {}) or {}
    object_name = _non_empty(payload.get("objectName")) or _non_empty(raw_args.get("instType")) or UNCATEGORIZED_OBJECT
    cmd_name = _non_empty(payload.get("cmdName")) or _non_empty(raw_args.get("cmdName")) or _non_empty(payload.get("methodName")) or UNKNOWN_COMMAND
    slot_id = payload.get("slotId")
    if slot_id is None:
        slot_id = raw_args.get("slotId")
    slot_id = _normalize_slot_id(slot_id)
    params = payload.get("params")
    if params is None:
        params = raw_args.get("params") if isinstance(raw_args, dict) else None
    if not isinstance(params, dict):
        params = {}
    fingerprint = params_fingerprint(params)
    return {
        "object_name": object_name,
        "cmd_name": cmd_name,
        "slot_id": slot_id,
        "slot_key": slot_key(slot_id),
        "description": payload.get("description") or "",
        "params": params,
        "params_fingerprint": fingerprint,
        "params_summary": params_summary(params),
        "raw_args": raw_args,
        "parameter_meta": payload.get("parameterMeta", []),
        "service_name": payload.get("serviceName"),
        "class_name": payload.get("className"),
        "method_name": payload.get("methodName"),
        "display_name": payload.get("displayName"),
    }


def _non_empty(value):
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _normalize_slot_id(value):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def slot_key(slot_id):
    return NULL_SLOT_KEY if slot_id is None else str(slot_id)


def params_fingerprint(params):
    return sha256(normalized_params_json(params).encode("utf-8")).hexdigest()


def normalized_params_json(params):
    return json.dumps(params or {}, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def params_summary(params):
    if not params:
        return "{}"
    parts = []
    for key in sorted(params.keys())[:4]:
        value = params[key]
        if isinstance(value, (dict, list)):
            rendered = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        else:
            rendered = str(value)
        if len(rendered) > 32:
            rendered = rendered[:29] + "..."
        parts.append(f"{key}={rendered}")
    if len(params) > 4:
        parts.append("...")
    return ", ".join(parts)


def resolve_interface_for_call(call_data, session_id, now):
    existing_id = find_interface_id(call_data, session_id)
    if existing_id:
        return upsert_interface(call_data, session_id, now), 1, 1
    if interface_locked():
        return None, 0, 0
    return upsert_interface(call_data, session_id, now), 1, 1


def find_interface_id(call_data, session_id):
    row = get_db().execute(
        "SELECT id FROM discovered_interface WHERE session_id=? AND object_name=? AND cmd_name=? AND slot_key=?",
        (session_id, call_data["object_name"], call_data["cmd_name"], call_data["slot_key"]),
    ).fetchone()
    return row["id"] if row else None


def upsert_interface(call_data, session_id, now):
    db = get_db()
    interface_id = uuid.uuid5(
        uuid.NAMESPACE_URL,
        "|".join([session_id, call_data["object_name"], call_data["cmd_name"], call_data["slot_key"]]),
    ).hex
    schema = params_schema(call_data["params"])
    existing = db.execute(
        "SELECT id FROM discovered_interface WHERE session_id=? AND object_name=? AND cmd_name=? AND slot_key=?",
        (session_id, call_data["object_name"], call_data["cmd_name"], call_data["slot_key"]),
    ).fetchone()
    is_new_sample = upsert_param_sample(interface_id, call_data, now)
    if existing:
        db.execute(
            """UPDATE discovered_interface
               SET description=?, latest_params_json=?, latest_params_fingerprint=?, params_schema_json=?,
                   parameter_schema_json=?, sample_args_json=?, params_summary=?,
                   service_name=?, class_name=?, method_name=?, display_name=?,
                   last_seen_at=?, call_count=call_count+1,
                   params_sample_count=params_sample_count+?, updated_at=?
               WHERE id=?""",
            (
                call_data["description"],
                dumps(call_data["params"]),
                call_data["params_fingerprint"],
                dumps(schema),
                dumps(schema),
                dumps(call_data["raw_args"]),
                call_data["params_summary"],
                call_data["service_name"],
                call_data["class_name"],
                call_data["method_name"],
                call_data["display_name"],
                now,
                1 if is_new_sample else 0,
                now,
                existing["id"],
            ),
        )
        return existing["id"]
    db.execute(
        """INSERT INTO discovered_interface
        (id, session_id, object_name, cmd_name, slot_id, slot_key, service_name, class_name, method_name,
         interface_key, http_method, request_uri, query_signature, body_signature, content_type,
         interface_alias, display_name, description, parameter_schema_json, params_schema_json,
         sample_args_json, latest_params_json, latest_params_fingerprint, params_sample_count, params_summary,
         first_seen_at, last_seen_at, call_count, success_count, exception_count, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, 1, 0, 0, ?, ?)""",
        (
            interface_id,
            session_id,
            call_data["object_name"],
            call_data["cmd_name"],
            call_data["slot_id"],
            call_data["slot_key"],
            call_data["service_name"],
            call_data["class_name"],
            call_data["method_name"],
            f"{call_data['object_name']} {call_data['cmd_name']} {call_data['slot_key']}",
            "DEBUG",
            call_data["cmd_name"],
            "",
            call_data["params_fingerprint"],
            "",
            None,
            call_data["display_name"],
            call_data["description"],
            dumps(schema),
            dumps(schema),
            dumps(call_data["raw_args"]),
            dumps(call_data["params"]),
            call_data["params_fingerprint"],
            call_data["params_summary"],
            now,
            now,
            now,
            now,
        ),
    )
    return interface_id


def upsert_param_sample(interface_id, call_data, now):
    db = get_db()
    sample_id = uuid.uuid5(uuid.NAMESPACE_URL, "|".join([interface_id, call_data["params_fingerprint"]])).hex
    existing = db.execute(
        "SELECT id FROM interface_param_sample WHERE interface_id=? AND params_fingerprint=?",
        (interface_id, call_data["params_fingerprint"]),
    ).fetchone()
    if existing:
        db.execute(
            """UPDATE interface_param_sample
               SET params_json=?, last_seen_at=?, seen_count=seen_count+1
               WHERE id=?""",
            (dumps(call_data["params"]), now, existing["id"]),
        )
        return False
    db.execute(
        """INSERT INTO interface_param_sample
           (id, interface_id, params_fingerprint, params_json, first_seen_at, last_seen_at, seen_count)
           VALUES (?, ?, ?, ?, ?, ?, 1)""",
        (sample_id, interface_id, call_data["params_fingerprint"], dumps(call_data["params"]), now, now),
    )
    return True


def params_schema(params):
    schema = {}
    for key, value in (params or {}).items():
        schema[key] = {"name": key, "type": type(value).__name__, "sample": value}
    return schema


def update_interface_stats(call_row, payload, now):
    db = get_db()
    interface = db.execute("SELECT * FROM discovered_interface WHERE id=?", (call_row["interface_id"],)).fetchone()
    if not interface:
        return
    success_delta = 1 if payload.get("success") else 0
    exception_delta = 0 if payload.get("success") else 1
    cost = payload.get("costMs") or 0
    completed = (interface["success_count"] or 0) + (interface["exception_count"] or 0)
    avg = cost if completed == 0 or interface["avg_cost_ms"] is None else ((interface["avg_cost_ms"] * completed) + cost) / (completed + 1)
    max_cost = cost if interface["max_cost_ms"] is None or interface["max_cost_ms"] < cost else interface["max_cost_ms"]
    min_cost = cost if interface["min_cost_ms"] is None or interface["min_cost_ms"] > cost else interface["min_cost_ms"]
    db.execute(
        """UPDATE discovered_interface
           SET success_count=success_count+?, exception_count=exception_count+?,
               avg_cost_ms=?, max_cost_ms=?, min_cost_ms=?, updated_at=?
           WHERE id=?""",
        (success_delta, exception_delta, avg, max_cost, min_cost, now, call_row["interface_id"]),
    )


def match_breakpoint(call_data, session_id):
    db = get_db()
    rows = db.execute(
        """SELECT * FROM breakpoint
           WHERE enabled=1 AND session_id=? AND object_name=? AND cmd_name=? AND slot_key=?
           ORDER BY created_at ASC""",
        (session_id, call_data["object_name"], call_data["cmd_name"], call_data["slot_key"]),
    ).fetchall()
    for row in rows:
        item = normalize(row_to_dict(row))
        if _breakpoint_matches(item, call_data):
            if _should_pause(item):
                return item
            _increment_breakpoint_count(db, item, now_iso())
    return None


def _breakpoint_matches(item, call_data):
    mode = item.get("match_mode") or "command_only"
    if mode == "command_only":
        return True
    if mode == "params_snapshot":
        return item.get("params_fingerprint") == call_data["params_fingerprint"]
    if mode == "params_condition":
        return _conditions_match(item.get("conditions") or [], call_data["params"])
    return False


def _conditions_match(conditions, params):
    for condition in conditions:
        path = condition.get("path", "")
        key = path.removeprefix("params.")
        op = condition.get("operator", "eq")
        expected = condition.get("value")
        exists = key in params
        actual = params.get(key)
        if op == "exists" and not exists:
            return False
        if op == "eq" and (not exists or actual != expected):
            return False
    return True


def _should_pause(item):
    hit_mode = item.get("hit_mode") or "always"
    if hit_mode in ("always", "once"):
        return True
    if hit_mode == "hit_count":
        limit = item.get("hit_limit") or 1
        return (item.get("hit_count") or 0) + 1 >= limit
    return True


def _apply_breakpoint_hit(db, item, now):
    if (item.get("hit_mode") or "always") == "once":
        db.execute("UPDATE breakpoint SET hit_count=hit_count+1, enabled=0, updated_at=? WHERE id=?", (now, item["id"]))
    else:
        _increment_breakpoint_count(db, item, now)


def _increment_breakpoint_count(db, item, now):
    db.execute("UPDATE breakpoint SET hit_count=hit_count+1, updated_at=? WHERE id=?", (now, item["id"]))


def continue_call(call_id):
    now = now_iso()
    released = wait_manager.continue_one(call_id)
    get_db().execute(
        "UPDATE call_record SET status='continued', continued_at=?, updated_at=? WHERE call_id=?",
        (now, now, call_id),
    )
    get_db().commit()
    return {"success": True, "released": released}


def continue_all_calls():
    now = now_iso()
    session_id = STATE["sessionId"]
    count = wait_manager.continue_all()
    if session_id:
        get_db().execute(
            "UPDATE call_record SET status='continued', continued_at=?, updated_at=? WHERE session_id=? AND status='paused'",
            (now, now, session_id),
        )
    get_db().commit()
    return {"success": True, "releasedCount": count}


def export_session_archive(session_id, payload=None):
    payload = payload or {}
    db = get_db()
    session = db.execute("SELECT * FROM debug_session WHERE id=?", (session_id,)).fetchone()
    if not session:
        return {"success": False, "message": "session not found"}
    archive_name = str(payload.get("archiveName") or session_id).strip() or session_id
    archive = {
        "format": MBREC_FORMAT,
        "extension": ".mbrec",
        "version": MBREC_VERSION,
        "archiveId": payload.get("archiveId") or f"mbrec-{uuid.uuid4().hex}",
        "archiveName": archive_name,
        "remark": payload.get("remark", ""),
        "exportedAt": now_iso(),
        "sourceSessionId": session_id,
        "session": row_to_dict(session),
        "calls": _archive_rows("SELECT * FROM call_record WHERE session_id=? ORDER BY call_index ASC, id ASC", (session_id,)),
        "interfaces": _archive_rows("SELECT * FROM discovered_interface WHERE session_id=? ORDER BY first_seen_at ASC", (session_id,)),
        "interfaceParamSamples": _archive_rows(
            """SELECT s.* FROM interface_param_sample s
               JOIN discovered_interface i ON s.interface_id=i.id
               WHERE i.session_id=?
               ORDER BY s.first_seen_at ASC""",
            (session_id,),
        ),
        "breakpoints": _archive_rows("SELECT * FROM breakpoint WHERE session_id=? ORDER BY created_at ASC", (session_id,)),
    }
    return {"success": True, "archive": archive}


def import_session_archive(archive, lock_interfaces=False):
    if not isinstance(archive, dict):
        return {"success": False, "message": "invalid archive"}
    if archive.get("format") != MBREC_FORMAT or archive.get("version") != MBREC_VERSION:
        return {"success": False, "message": "unsupported archive"}
    archive_id = archive.get("archiveId")
    if not archive_id:
        return {"success": False, "message": "archiveId missing"}

    released = stop_debug()
    db = get_db()
    existing = db.execute("SELECT id FROM debug_session WHERE archive_id=?", (archive_id,)).fetchone()
    if existing:
        return {
            "success": False,
            "message": "archive already imported",
            "archiveId": archive_id,
            "existingSessionId": existing["id"],
            "openExisting": True,
            "releasedCount": released,
        }

    now = now_iso()
    source = archive.get("session") or {}
    new_session_id = f"session-{uuid.uuid4().hex[:10]}"
    archive_name = str(archive.get("archiveName") or source.get("id") or new_session_id).strip() or new_session_id
    archive_remark = str(archive.get("remark") or "")
    interface_ids = {}
    call_ids = {}

    try:
        db.execute(
            """INSERT INTO debug_session
               (id, mode, status, service_name, operator, start_time, end_time, recording, debugging, remark,
                archive_id, archive_name, archive_remark, imported_at, created_at, updated_at)
               VALUES (?, 'idle', 'idle', ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, ?)""",
            (
                new_session_id,
                source.get("service_name", "instrument-service-demo"),
                source.get("operator", "developer"),
                source.get("start_time") or source.get("created_at") or now,
                source.get("end_time"),
                archive_remark or source.get("remark", ""),
                archive_id,
                archive_name,
                archive_remark,
                now,
                source.get("created_at") or now,
                now,
            ),
        )

        for item in archive.get("interfaces") or []:
            old_id = item.get("id")
            new_id = _imported_interface_id(new_session_id, item)
            interface_ids[old_id] = new_id
            _insert_archive_row(
                db,
                "discovered_interface",
                item,
                {
                    "id": new_id,
                    "session_id": new_session_id,
                    "created_at": item.get("created_at") or now,
                    "updated_at": item.get("updated_at") or now,
                },
            )

        for item in archive.get("interfaceParamSamples") or []:
            old_interface_id = item.get("interface_id")
            new_interface_id = interface_ids.get(old_interface_id)
            if not new_interface_id:
                continue
            fingerprint = item.get("params_fingerprint") or uuid.uuid4().hex
            _insert_archive_row(
                db,
                "interface_param_sample",
                item,
                {
                    "id": uuid.uuid5(uuid.NAMESPACE_URL, "|".join([new_interface_id, fingerprint])).hex,
                    "interface_id": new_interface_id,
                },
            )

        for index, item in enumerate(archive.get("calls") or [], start=1):
            old_call_id = item.get("call_id") or f"call-{index}"
            new_call_id = _imported_call_id(new_session_id, old_call_id)
            call_ids[old_call_id] = new_call_id
            old_interface_id = item.get("interface_id")
            new_interface_id = interface_ids.get(old_interface_id)
            interface_registered = 1 if new_interface_id else int(item.get("interface_registered", 0) or 0)
            _insert_archive_row(
                db,
                "call_record",
                item,
                {
                    "call_id": new_call_id,
                    "session_id": new_session_id,
                    "interface_id": new_interface_id,
                    "interface_registered": interface_registered,
                    "discovery_enabled": int(item.get("discovery_enabled", interface_registered) or 0),
                    "created_at": item.get("created_at") or now,
                    "updated_at": item.get("updated_at") or now,
                },
                omit=("id",),
            )

        for item in archive.get("breakpoints") or []:
            old_id = item.get("id") or uuid.uuid4().hex
            _insert_archive_row(
                db,
                "breakpoint",
                item,
                {
                    "id": _imported_breakpoint_id(new_session_id, old_id),
                    "session_id": new_session_id,
                    "source_session_id": new_session_id if item.get("source_session_id") else item.get("source_session_id"),
                    "source_interface_id": interface_ids.get(item.get("source_interface_id")),
                    "source_call_id": call_ids.get(item.get("source_call_id")),
                    "created_at": item.get("created_at") or now,
                    "updated_at": item.get("updated_at") or now,
                },
            )

        if lock_interfaces:
            db.execute(
                """INSERT INTO app_setting (key, value, updated_at)
                   VALUES (?, '1', ?)
                   ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at""",
                (INTERFACE_LOCK_SETTING, now),
            )
        db.commit()
    except Exception:
        db.rollback()
        raise

    STATE.update(debugging=False, mode="idle", sessionId=new_session_id)
    return state_response(
        success=True,
        sessionId=new_session_id,
        importedSessionId=new_session_id,
        archiveId=archive_id,
        archiveName=archive_name,
        releasedCount=released,
    )


def _archive_rows(sql, args):
    return [row_to_dict(row) for row in get_db().execute(sql, args).fetchall()]


def _insert_archive_row(db, table, row, overrides=None, omit=()):
    columns = [item["name"] for item in db.execute(f"PRAGMA table_info({table})").fetchall()]
    values = {}
    for column in columns:
        if column in omit:
            continue
        if column in row:
            values[column] = row.get(column)
    for key, value in (overrides or {}).items():
        if key in columns and key not in omit:
            values[key] = value
    names = list(values.keys())
    placeholders = ", ".join("?" for _ in names)
    db.execute(
        f"INSERT INTO {table} ({', '.join(names)}) VALUES ({placeholders})",
        [values[name] for name in names],
    )


def _imported_interface_id(session_id, item):
    parts = [
        session_id,
        item.get("object_name") or UNCATEGORIZED_OBJECT,
        item.get("cmd_name") or UNKNOWN_COMMAND,
        item.get("slot_key") or slot_key(item.get("slot_id")),
    ]
    return uuid.uuid5(uuid.NAMESPACE_URL, "|".join(str(part) for part in parts)).hex


def _imported_call_id(session_id, old_call_id):
    return f"call-{uuid.uuid5(uuid.NAMESPACE_URL, '|'.join([session_id, str(old_call_id)])).hex[:16]}"


def _imported_breakpoint_id(session_id, old_breakpoint_id):
    return f"bp-{uuid.uuid5(uuid.NAMESPACE_URL, '|'.join([session_id, str(old_breakpoint_id)])).hex[:16]}"


def list_sessions():
    rows = get_db().execute(
        """SELECT s.*,
            (SELECT COUNT(*) FROM call_record c WHERE c.session_id=s.id) AS call_count,
            (SELECT COUNT(*) FROM discovered_interface i WHERE i.session_id=s.id) AS interface_count,
            (SELECT COUNT(*) FROM breakpoint b WHERE b.session_id=s.id) AS breakpoint_count,
            (SELECT COUNT(*) FROM call_record c WHERE c.session_id=s.id AND c.status='exception') AS exception_count
           FROM debug_session s ORDER BY s.created_at DESC"""
    ).fetchall()
    return [row_to_dict(row) for row in rows]


def list_calls(session_id=None, object_name=None, keyword=None, status=None, sort_by=None, sort_order=None):
    sid = session_id or STATE["sessionId"]
    if not sid:
        return []
    rows = get_db().execute(
        """SELECT c.*, i.interface_alias
           FROM call_record c
           LEFT JOIN discovered_interface i ON c.interface_id=i.id
           WHERE c.session_id=?
           ORDER BY c.id DESC""",
        (sid,),
    ).fetchall()
    items = [normalize(row_to_dict(row)) for row in rows]
    return filter_items(items, object_name, keyword, status, sort_by, sort_order)


def list_interfaces(session_id=None, object_name=None, keyword=None, status=None, sort_by=None, sort_order=None):
    sid = session_id or STATE["sessionId"]
    if not sid:
        return []
    rows = get_db().execute(
        "SELECT * FROM discovered_interface WHERE session_id=? ORDER BY last_seen_at DESC",
        (sid,),
    ).fetchall()
    items = [normalize(row_to_dict(row)) for row in rows]
    return filter_items(items, object_name, keyword, status, sort_by, sort_order)


def register_interface_from_call(call_id):
    db = get_db()
    row = db.execute("SELECT * FROM call_record WHERE call_id=?", (call_id,)).fetchone()
    if not row:
        return {"success": False, "message": "call not found"}
    call = normalize(row_to_dict(row))
    if call.get("interface_id") and call.get("interface_registered", 1):
        return {"success": True, "interfaceId": call["interface_id"], "alreadyRegistered": True}
    now = now_iso()
    call_data = call_data_from_record(call)
    interface_id = upsert_interface(call_data, call["session_id"], now)
    db.execute(
        "UPDATE call_record SET interface_id=?, interface_registered=1, discovery_enabled=1, updated_at=? WHERE call_id=?",
        (interface_id, now, call_id),
    )
    if call.get("status") in ("finished", "exception"):
        update_interface_stats(
            {"interface_id": interface_id},
            {"success": bool(call.get("success")), "costMs": call.get("cost_ms")},
            now,
        )
    db.commit()
    return {"success": True, "interfaceId": interface_id, "callId": call_id}


def call_data_from_record(call):
    params = call.get("params") or {}
    raw_args = call.get("raw_args") or call.get("args") or {}
    fingerprint = call.get("params_fingerprint") or params_fingerprint(params)
    return {
        "object_name": call.get("object_name") or UNCATEGORIZED_OBJECT,
        "cmd_name": call.get("cmd_name") or UNKNOWN_COMMAND,
        "slot_id": _normalize_slot_id(call.get("slot_id")),
        "slot_key": call.get("slot_key") or slot_key(_normalize_slot_id(call.get("slot_id"))),
        "description": call.get("description") or "",
        "params": params,
        "params_fingerprint": fingerprint,
        "params_summary": call.get("params_summary") or params_summary(params),
        "raw_args": raw_args,
        "parameter_meta": call.get("parameter_meta") or [],
        "service_name": call.get("service_name"),
        "class_name": call.get("class_name"),
        "method_name": call.get("method_name"),
        "display_name": call.get("display_name"),
    }


def filter_items(items, object_name=None, keyword=None, status=None, sort_by=None, sort_order=None):
    result = []
    needle = (keyword or "").lower()
    for item in items:
        if object_name and item.get("object_name") != object_name:
            continue
        haystack = " ".join(str(item.get(key) or "") for key in ("object_name", "cmd_name", "description", "params_summary", "exception_message")).lower()
        if needle and needle not in haystack:
            continue
        if status and item.get("status") != status:
            continue
        result.append(item)
    if sort_by:
        key = snake_case(sort_by)
        result.sort(key=lambda item: item.get(key) or "", reverse=(sort_order or "").lower() == "desc")
    return result


def grouped_calls(session_id=None):
    return grouped("calls", list_calls(session_id))


def grouped_interfaces(session_id=None):
    return grouped("interfaces", list_interfaces(session_id))


def grouped(kind, items):
    groups = {}
    for item in items:
        object_name = item.get("object_name") or UNCATEGORIZED_OBJECT
        group = groups.setdefault(object_name, {"objectName": object_name, "items": []})
        group["items"].append(item)
    result = []
    for object_name, group in groups.items():
        rows = group["items"]
        group["callCount"] = sum(item.get("call_count", 1) or 1 for item in rows) if kind == "interfaces" else len(rows)
        group["interfaceCount"] = len(rows) if kind == "interfaces" else 0
        group["pausedCount"] = sum(1 for item in rows if item.get("status") == "paused")
        group["exceptionCount"] = sum((item.get("exception_count") or 0) if kind == "interfaces" else (1 if item.get("status") == "exception" else 0) for item in rows)
        group["lastSeenAt"] = max([item.get("last_seen_at") or item.get("updated_at") or "" for item in rows] or [""])
        result.append(group)
    result.sort(key=lambda group: group["objectName"])
    return result


def list_breakpoints(session_id=None):
    sid = session_id or STATE["sessionId"]
    if not sid:
        return []
    rows = get_db().execute(
        """SELECT b.*, COALESCE(i.interface_alias, ci.interface_alias) AS interface_alias
           FROM breakpoint b
           LEFT JOIN discovered_interface i ON b.source_interface_id=i.id
           LEFT JOIN call_record c ON b.source_call_id=c.call_id
           LEFT JOIN discovered_interface ci ON c.interface_id=ci.id
           WHERE b.session_id=?
           ORDER BY b.created_at DESC""",
        (sid,),
    ).fetchall()
    return [normalize(row_to_dict(row)) for row in rows]


def update_interface_alias(interface_id, alias):
    db = get_db()
    row = db.execute("SELECT id FROM discovered_interface WHERE id=?", (interface_id,)).fetchone()
    if not row:
        return {"success": False, "message": "interface not found"}
    now = now_iso()
    db.execute(
        "UPDATE discovered_interface SET interface_alias=?, updated_at=? WHERE id=?",
        ((alias or "").strip(), now, interface_id),
    )
    db.commit()
    return {"success": True, "interfaceId": interface_id, "interfaceAlias": (alias or "").strip()}


def create_breakpoint(data):
    session_id = data.get("sessionId") or STATE["sessionId"]
    if not session_id:
        return {"success": False, "message": "请先新建或选择 Session"}
    now = now_iso()
    bp_id = f"bp-{uuid.uuid4().hex[:10]}"
    slot_id = _normalize_slot_id(data.get("slotId"))
    slot = data.get("slotKey") or slot_key(slot_id)
    object_name = data.get("objectName") or UNCATEGORIZED_OBJECT
    cmd_name = data.get("cmdName") or UNKNOWN_COMMAND
    match_mode = data.get("matchMode") or "command_only"
    get_db().execute(
        """INSERT INTO breakpoint
        (id, name, enabled, scope, session_id, object_name, cmd_name, slot_id, slot_key, match_mode,
         params_fingerprint, params_snapshot_json, conditions_json, condition_json, hit_mode, hit_count,
         hit_limit, source_type, source_session_id, source_interface_id, source_call_id,
         service_name, class_name, method_name, display_name, created_at, updated_at)
        VALUES (?, ?, ?, 'session', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            bp_id,
            data.get("name") or f"{object_name} {cmd_name} breakpoint",
            1 if data.get("enabled", True) else 0,
            session_id,
            object_name,
            cmd_name,
            slot_id,
            slot,
            match_mode,
            data.get("paramsFingerprint"),
            dumps(data.get("paramsSnapshot")),
            dumps(data.get("conditions", [])),
            dumps(data.get("condition", {})),
            data.get("hitMode", "always"),
            data.get("hitLimit"),
            data.get("sourceType"),
            data.get("sourceSessionId") or session_id,
            data.get("sourceInterfaceId"),
            data.get("sourceCallId"),
            data.get("serviceName"),
            data.get("className"),
            data.get("methodName"),
            data.get("displayName"),
            now,
            now,
        ),
    )
    get_db().commit()
    return {"success": True, "breakpointId": bp_id}


def breakpoint_from_interface(interface_id, body):
    row = get_db().execute("SELECT * FROM discovered_interface WHERE id=?", (interface_id,)).fetchone()
    if not row:
        return {"success": False, "message": "interface not found"}
    item = normalize(row_to_dict(row))
    match_mode = body.get("matchMode", "command_only")
    return create_breakpoint(
        {
            "name": body.get("name") or f"{item.get('interface_alias') or item['object_name'] + ' ' + item['cmd_name']} breakpoint",
            "enabled": body.get("enabled", True),
            "sessionId": item["session_id"],
            "objectName": item["object_name"],
            "cmdName": item["cmd_name"],
            "slotId": item["slot_id"],
            "slotKey": item["slot_key"],
            "matchMode": match_mode,
            "paramsFingerprint": item["latest_params_fingerprint"] if match_mode == "params_snapshot" else None,
            "paramsSnapshot": item.get("latest_params") if match_mode == "params_snapshot" else None,
            "hitMode": body.get("hitMode", "always"),
            "sourceType": "interface",
            "sourceSessionId": item["session_id"],
            "sourceInterfaceId": interface_id,
            "serviceName": item.get("service_name"),
            "className": item.get("class_name"),
            "methodName": item.get("method_name"),
            "displayName": item.get("display_name"),
        }
    )


def breakpoint_from_call(call_id, body):
    row = get_db().execute("SELECT * FROM call_record WHERE call_id=?", (call_id,)).fetchone()
    if not row:
        return {"success": False, "message": "call not found"}
    call = normalize(row_to_dict(row))
    match_mode = body.get("matchMode", "command_only")
    return create_breakpoint(
        {
            "name": body.get("name") or f"{call['object_name']} {call['cmd_name']} breakpoint",
            "enabled": body.get("enabled", True),
            "sessionId": call["session_id"],
            "objectName": call["object_name"],
            "cmdName": call["cmd_name"],
            "slotId": call["slot_id"],
            "slotKey": call["slot_key"],
            "matchMode": match_mode,
            "paramsFingerprint": call["params_fingerprint"] if match_mode == "params_snapshot" else None,
            "paramsSnapshot": call.get("params") if match_mode == "params_snapshot" else None,
            "hitMode": body.get("hitMode", "always"),
            "sourceType": "call",
            "sourceSessionId": call["session_id"],
            "sourceInterfaceId": call.get("interface_id"),
            "sourceCallId": call_id,
            "serviceName": call.get("service_name"),
            "className": call.get("class_name"),
            "methodName": call.get("method_name"),
            "displayName": call.get("display_name"),
        }
    )


def normalize(row):
    if not row:
        return row
    for key in list(row.keys()):
        if key.endswith("_json"):
            row[key[:-5]] = loads(row[key], None)
    return row


def snake_case(value):
    chars = []
    for char in value:
        if char.isupper():
            chars.append("_")
            chars.append(char.lower())
        else:
            chars.append(char)
    return "".join(chars).lstrip("_")
