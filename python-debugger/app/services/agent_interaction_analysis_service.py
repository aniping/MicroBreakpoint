from app.db.database import get_db
from app.services.debug_service import STATE, row_to_dict


def analyze_interactions(payload):
    session_id = payload.get("sessionId") or payload.get("session_id") or STATE["sessionId"]
    if not session_id:
        return {
            "ok": True,
            "interactions": [],
            "summary": {"returned_count": 0},
            "entities": [],
            "message": "请先新建或选择会话。",
        }
    target = payload.get("target") if isinstance(payload.get("target"), dict) else {}
    filters = payload.get("filters") if isinstance(payload.get("filters"), dict) else {}
    object_name = target.get("object") or target.get("objectName") or ""
    cmd_name = target.get("command") or target.get("cmdName") or ""
    status = filters.get("status") or payload.get("status") or ""
    limit = max(1, min(50, int_or_default(filters.get("limit", payload.get("limit")), 20)))

    clauses = ["session_id=?"]
    args = [session_id]
    if object_name:
        clauses.append("object_name=?")
        args.append(object_name)
    if cmd_name:
        clauses.append("cmd_name=?")
        args.append(cmd_name)
    if status:
        clauses.append("status=?")
        args.append(status)

    rows = get_db().execute(
        f"""SELECT call_id, object_name, cmd_name, status, breakpoint_id, breakpoint_name,
                   params_summary, result_summary, params_payload_id, result_payload_id,
                   exception_type, exception_message, cost_ms, created_at, finished_at, updated_at
            FROM call_record
            WHERE {' AND '.join(clauses)}
            ORDER BY updated_at DESC, id DESC
            LIMIT ?""",
        args + [limit],
    ).fetchall()

    interactions = [interaction(row_to_dict(row)) for row in rows]
    entities = []
    status_counts = {}
    for item in interactions:
        status_counts[item["status"]] = status_counts.get(item["status"], 0) + 1
        entities.append(entity("interaction", item["interaction_id"], item["label"], item["status"]))
        add_payload_entity(entities, item.get("request_payload_ref"), f"{item['label']} request")
        add_payload_entity(entities, item.get("response_payload_ref"), f"{item['label']} response")
    return {
        "ok": True,
        "interactions": interactions,
        "summary": {
            "returned_count": len(interactions),
            "status_counts": status_counts,
        },
        "entities": entities,
    }


def interaction(row):
    label = f"{row.get('object_name')}.{row.get('cmd_name')}"
    exception_summary = {}
    if row.get("exception_type") or row.get("exception_message"):
        exception_summary = {"type": row.get("exception_type") or "", "message": row.get("exception_message") or ""}
    return {
        "interaction_id": row.get("call_id"),
        "label": label,
        "status": row.get("status"),
        "breakpoint_rule_id": row.get("breakpoint_id"),
        "request_payload_ref": row.get("params_payload_id"),
        "response_payload_ref": row.get("result_payload_id"),
        "request_summary": row.get("params_summary"),
        "response_summary": row.get("result_summary"),
        "exception_summary": exception_summary,
        "cost_ms": row.get("cost_ms"),
        "started_at": row.get("created_at"),
        "finished_at": row.get("finished_at"),
        "updated_at": row.get("updated_at"),
    }


def add_payload_entity(entities, payload_ref, label):
    if payload_ref:
        entities.append(entity("payload", payload_ref, label, "available"))


def entity(entity_type, entity_id, label, status):
    return {
        "type": entity_type,
        "id": entity_id,
        "label": label,
        "status": status,
    }


def int_or_default(value, default):
    try:
        return int(value if value is not None else default)
    except (TypeError, ValueError):
        return default
