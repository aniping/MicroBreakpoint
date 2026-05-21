import uuid

from app.db.database import get_db, row_to_dict
from app.services.wait_manager import wait_manager
from app.utils.json_utils import dumps, loads
from app.utils.time_utils import now_iso

STATE = {"recording": False, "debugging": False, "mode": "idle", "sessionId": None}


def create_session(payload):
    stop_activity()
    session_id = f"session-{uuid.uuid4().hex[:10]}"
    now = now_iso()
    STATE.update(recording=False, debugging=False, mode="idle", sessionId=session_id)
    db = get_db()
    db.execute(
        """INSERT INTO debug_session
        (id, mode, service_name, operator, start_time, recording, debugging, remark, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            session_id,
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
    stop_activity()
    row = get_db().execute("SELECT id FROM debug_session WHERE id=?", (session_id,)).fetchone()
    if not row:
        return {"success": False, "message": "session not found"}
    STATE.update(recording=False, debugging=False, mode="idle", sessionId=session_id)
    return state_response(success=True, sessionId=session_id)


def start_session(mode, payload):
    if not STATE["sessionId"]:
        return {"success": False, "message": "请先新建或选择会话", **state_response()}
    now = now_iso()
    STATE.update(recording=True, debugging=mode == "debug", mode=mode)
    db = get_db()
    db.execute(
        "UPDATE debug_session SET mode=?, recording=1, debugging=?, end_time=NULL, updated_at=? WHERE id=?",
        (mode, 1 if mode == "debug" else 0, now, STATE["sessionId"]),
    )
    db.commit()
    return state_response(success=True)


def stop_activity():
    released = wait_manager.continue_all()
    if STATE["sessionId"]:
        now = now_iso()
        db = get_db()
        db.execute(
            "UPDATE debug_session SET end_time=?, recording=0, debugging=0, updated_at=? WHERE id=?",
            (now, now, STATE["sessionId"]),
        )
        db.commit()
    STATE.update(recording=False, debugging=False, mode="idle")
    return released


def state_response(**extra):
    db = get_db()
    session_filter = "WHERE session_id=?" if STATE["sessionId"] else ""
    session_args = (STATE["sessionId"],) if STATE["sessionId"] else ()
    counts = {
        "hasSession": STATE["sessionId"] is not None,
        "callCount": db.execute(f"SELECT COUNT(*) FROM call_record {session_filter}", session_args).fetchone()[0],
        "discoveredInterfaceCount": db.execute(f"SELECT COUNT(*) FROM discovered_interface {session_filter}", session_args).fetchone()[0],
        "breakpointCount": breakpoint_count(db),
        "pausedCount": db.execute(
            f"SELECT COUNT(*) FROM call_record {'WHERE session_id=? AND status=?' if STATE['sessionId'] else 'WHERE status=?'}",
            (STATE["sessionId"], "paused") if STATE["sessionId"] else ("paused",),
        ).fetchone()[0],
    }
    return {**STATE, **counts, **extra}


def breakpoint_count(db):
    if not STATE["sessionId"]:
        return db.execute("SELECT COUNT(*) FROM breakpoint").fetchone()[0]
    return db.execute(
        "SELECT COUNT(*) FROM breakpoint WHERE source_session_id IS NULL OR source_session_id=?",
        (STATE["sessionId"],),
    ).fetchone()[0]


def before_call(payload):
    if not STATE["recording"]:
        return {"success": True, "callIndex": 0, "action": "continue"}

    db = get_db()
    now = now_iso()
    session_id = STATE["sessionId"]
    call_index = db.execute("SELECT COUNT(*) FROM call_record WHERE session_id=?", (session_id,)).fetchone()[0] + 1
    db.execute(
        """INSERT OR REPLACE INTO call_record
        (call_id, session_id, call_index, service_name, class_name, method_name, display_name, description,
         thread_name, args_json, parameter_meta_json, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'running', ?, ?)""",
        (
            payload["callId"],
            session_id,
            call_index,
            payload.get("serviceName"),
            payload.get("className"),
            payload.get("methodName"),
            payload.get("displayName"),
            payload.get("description"),
            payload.get("threadName"),
            dumps(payload.get("args", {})),
            dumps(payload.get("parameterMeta", [])),
            now,
            now,
        ),
    )
    interface_id = None
    if not STATE["debugging"]:
        interface_id = upsert_interface(payload, session_id, now)
    matched = match_breakpoint(payload)
    if STATE["debugging"] and matched:
        wait_manager.create(payload["callId"])
        db.execute(
            "UPDATE call_record SET status='paused', breakpoint_id=?, updated_at=? WHERE call_id=?",
            (matched["id"], now, payload["callId"]),
        )
        db.execute("UPDATE breakpoint SET hit_count=hit_count+1, updated_at=? WHERE id=?", (now, matched["id"]))
        db.commit()
        return {
            "success": True,
            "callIndex": call_index,
            "action": "pause",
            "reason": "matched breakpoint",
            "waitTimeoutMs": 300000,
            "breakpointId": matched["id"],
            "interfaceId": interface_id,
        }
    db.commit()
    return {"success": True, "callIndex": call_index, "action": "continue", "interfaceId": interface_id}


def after_call(payload):
    db = get_db()
    now = now_iso()
    status = "finished" if payload.get("success") else "exception"
    db.execute(
        """UPDATE call_record SET result_json=?, success=?, exception_type=?, exception_message=?,
           cost_ms=?, status=?, updated_at=? WHERE call_id=?""",
        (
            dumps(payload.get("result")),
            1 if payload.get("success") else 0,
            payload.get("exceptionType"),
            payload.get("exceptionMessage"),
            payload.get("costMs"),
            status,
            now,
            payload.get("callId"),
        ),
    )
    row = db.execute("SELECT * FROM call_record WHERE call_id=?", (payload.get("callId"),)).fetchone()
    if row and not STATE["debugging"]:
        update_interface_stats(row, payload, now)
    db.commit()
    return {"success": True}


def upsert_interface(payload, session_id, now):
    interface_id = uuid.uuid5(
        uuid.NAMESPACE_URL,
        "|".join([session_id, payload.get("serviceName", ""), payload.get("className", ""), payload.get("methodName", "")]),
    ).hex
    schema = {}
    args = payload.get("args", {})
    for item in payload.get("parameterMeta", []):
        name = item.get("name")
        schema[name] = {**item, "sample": args.get(name)}
    db = get_db()
    db.execute(
        """INSERT INTO discovered_interface
        (id, session_id, service_name, class_name, method_name, display_name, description,
         parameter_schema_json, sample_args_json, first_seen_at, last_seen_at, call_count,
         success_count, exception_count, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0, 0, ?, ?)
        ON CONFLICT(session_id, service_name, class_name, method_name)
        DO UPDATE SET display_name=excluded.display_name, description=excluded.description,
          parameter_schema_json=excluded.parameter_schema_json, sample_args_json=excluded.sample_args_json,
          last_seen_at=excluded.last_seen_at, call_count=discovered_interface.call_count+1,
          updated_at=excluded.updated_at""",
        (
            interface_id,
            session_id,
            payload.get("serviceName"),
            payload.get("className"),
            payload.get("methodName"),
            payload.get("displayName"),
            payload.get("description"),
            dumps(schema),
            dumps(args),
            now,
            now,
            now,
            now,
        ),
    )
    return interface_id


def update_interface_stats(call_row, payload, now):
    db = get_db()
    success_delta = 1 if payload.get("success") else 0
    exception_delta = 0 if payload.get("success") else 1
    cost = payload.get("costMs") or 0
    db.execute(
        """UPDATE discovered_interface
        SET success_count=success_count+?, exception_count=exception_count+?,
            avg_cost_ms=CASE WHEN avg_cost_ms IS NULL THEN ? ELSE (avg_cost_ms + ?) / 2 END,
            max_cost_ms=CASE WHEN max_cost_ms IS NULL OR max_cost_ms < ? THEN ? ELSE max_cost_ms END,
            min_cost_ms=CASE WHEN min_cost_ms IS NULL OR min_cost_ms > ? THEN ? ELSE min_cost_ms END,
            updated_at=?
        WHERE session_id=? AND service_name=? AND class_name=? AND method_name=?""",
        (
            success_delta,
            exception_delta,
            cost,
            cost,
            cost,
            cost,
            cost,
            cost,
            now,
            call_row["session_id"],
            call_row["service_name"],
            call_row["class_name"],
            call_row["method_name"],
        ),
    )


def match_breakpoint(payload):
    db = get_db()
    rows = db.execute("SELECT * FROM breakpoint WHERE enabled=1 AND method_name=?", (payload.get("methodName"),)).fetchall()
    args = payload.get("args", {})
    for row in rows:
        item = row_to_dict(row)
        if item["source_session_id"] and item["source_session_id"] != STATE["sessionId"]:
            continue
        if item["service_name"] and item["service_name"] != payload.get("serviceName"):
            continue
        if item["class_name"] and item["class_name"] != payload.get("className"):
            continue
        condition = loads(item["condition_json"], {}) or {}
        if all(args.get(k) == v for k, v in condition.items()):
            return item
    return None


def list_rows(table):
    return [normalize(row_to_dict(row)) for row in get_db().execute(f"SELECT * FROM {table} ORDER BY created_at DESC").fetchall()]


def list_sessions():
    rows = get_db().execute(
        """SELECT s.*,
            (SELECT COUNT(*) FROM call_record c WHERE c.session_id=s.id) AS call_count,
            (SELECT COUNT(*) FROM discovered_interface i WHERE i.session_id=s.id) AS interface_count,
            (SELECT COUNT(*) FROM call_record c WHERE c.session_id=s.id AND c.status='exception') AS exception_count
           FROM debug_session s ORDER BY s.created_at DESC"""
    ).fetchall()
    return [row_to_dict(row) for row in rows]


def list_calls(session_id=None):
    sid = session_id or STATE["sessionId"]
    if sid:
        rows = get_db().execute("SELECT * FROM call_record WHERE session_id=? ORDER BY id DESC", (sid,)).fetchall()
    else:
        rows = []
    return [normalize(row_to_dict(row)) for row in rows]


def list_interfaces(session_id=None):
    sid = session_id or STATE["sessionId"]
    if sid:
        rows = get_db().execute("SELECT * FROM discovered_interface WHERE session_id=? ORDER BY last_seen_at DESC", (sid,)).fetchall()
    else:
        rows = []
    return [normalize(row_to_dict(row)) for row in rows]


def list_breakpoints(session_id=None):
    sid = session_id or STATE["sessionId"]
    if sid:
        rows = get_db().execute(
            "SELECT * FROM breakpoint WHERE source_session_id IS NULL OR source_session_id=? ORDER BY created_at DESC",
            (sid,),
        ).fetchall()
    else:
        rows = get_db().execute("SELECT * FROM breakpoint ORDER BY created_at DESC").fetchall()
    return [normalize(row_to_dict(row)) for row in rows]


def normalize(row):
    for key in list(row.keys()):
        if key.endswith("_json"):
            row[key[:-5]] = loads(row[key], None)
    return row


def create_breakpoint(data):
    now = now_iso()
    bp_id = f"bp-{uuid.uuid4().hex[:10]}"
    get_db().execute(
        """INSERT INTO breakpoint
        (id, name, enabled, service_name, class_name, method_name, display_name, condition_json,
         hit_mode, hit_count, source_session_id, source_interface_id, source_call_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?)""",
        (
            bp_id,
            data.get("name") or f"{data.get('methodName')} breakpoint",
            1 if data.get("enabled", True) else 0,
            data.get("serviceName"),
            data.get("className"),
            data.get("methodName"),
            data.get("displayName"),
            dumps(data.get("condition", {})),
            data.get("hitMode", "always"),
            data.get("sourceSessionId"),
            data.get("sourceInterfaceId"),
            data.get("sourceCallId"),
            now,
            now,
        ),
    )
    get_db().commit()
    return {"success": True, "breakpointId": bp_id}
