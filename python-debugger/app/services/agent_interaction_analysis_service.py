from app.db.database import get_db
from app.services.debug_service import STATE, row_to_dict
from app.services.payload_store import payload_fragment_by_id


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
    exception_only = bool_value(
        filters.get(
            "exception_only",
            filters.get("exceptionOnly", payload.get("exception_only", payload.get("exceptionOnly"))),
        )
    )
    since = filters.get("since") or filters.get("from") or payload.get("since") or payload.get("from") or ""
    until = filters.get("until") or filters.get("to") or payload.get("until") or payload.get("to") or ""
    limit = max(1, min(50, int_or_default(filters.get("limit", payload.get("limit")), 20)))
    field_filter = field_filter_from(filters, payload)
    query_limit = 200 if field_filter["field_path"] else limit

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
    if exception_only:
        clauses.append("(status='exception' OR exception_type IS NOT NULL OR exception_message IS NOT NULL)")
    if since:
        clauses.append("created_at>=?")
        args.append(since)
    if until:
        clauses.append("created_at<=?")
        args.append(until)

    rows = get_db().execute(
        f"""SELECT call_id, object_name, cmd_name, status, breakpoint_id, breakpoint_name,
                   params_summary, result_summary, params_payload_id, result_payload_id,
                   exception_type, exception_message, cost_ms, created_at, finished_at, updated_at
            FROM call_record
            WHERE {' AND '.join(clauses)}
            ORDER BY updated_at DESC, id DESC
            LIMIT ?""",
        args + [query_limit],
    ).fetchall()

    interactions = []
    for row in rows:
        item = row_to_dict(row)
        if not matches_field_filter(item, field_filter):
            continue
        interactions.append(interaction(item))
        if len(interactions) >= limit:
            break
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
            "filters": {
                "exception_only": exception_only,
                "since": since,
                "until": until,
                "field_path": field_filter["field_path"],
                "field_value": field_filter["field_value"] if field_filter["has_field_value"] else None,
            },
        },
        "entities": entities,
    }


def compare_interactions(payload):
    ids = [str(item) for item in payload.get("interaction_ids", []) if str(item)]
    if len(ids) < 2:
        return {"ok": False, "status": "invalid_request", "message": "至少需要两个 interaction_id。", "entities": []}
    left_row = interaction_row(ids[0])
    right_row = interaction_row(ids[1])
    if not left_row or not right_row:
        return {"ok": False, "status": "not_found", "message": "交互记录不存在。", "entities": []}
    left = interaction(left_row)
    right = interaction(right_row)
    entities = [
        entity("interaction", left["interaction_id"], left["label"], left["status"]),
        entity("interaction", right["interaction_id"], right["label"], right["status"]),
    ]
    for item in (left, right):
        add_payload_entity(entities, item.get("request_payload_ref"), f"{item['label']} request")
        add_payload_entity(entities, item.get("response_payload_ref"), f"{item['label']} response")
    return {
        "ok": True,
        "base_interaction_id": left["interaction_id"],
        "compared_interaction_id": right["interaction_id"],
        "interactions": [left, right],
        "differences": differences(left, right),
        "entities": entities,
    }


def interaction_row(interaction_id):
    row = get_db().execute(
        """SELECT call_id, object_name, cmd_name, status, breakpoint_id, breakpoint_name,
                  params_summary, result_summary, params_payload_id, result_payload_id,
                  exception_type, exception_message, cost_ms, created_at, finished_at, updated_at
           FROM call_record
           WHERE call_id=?""",
        (interaction_id,),
    ).fetchone()
    return row_to_dict(row) if row else None


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
        "field_index": field_index(row),
        "exception_summary": exception_summary,
        "cost_ms": row.get("cost_ms"),
        "started_at": row.get("created_at"),
        "finished_at": row.get("finished_at"),
        "updated_at": row.get("updated_at"),
    }


def field_index(row):
    result = []
    result.extend(summary_fields(row.get("params_summary"), "request.parameters", row.get("params_payload_id")))
    result.extend(summary_fields(row.get("result_summary"), "response.result", row.get("result_payload_id")))
    return result


def summary_fields(summary, path_prefix, payload_ref):
    if not payload_ref:
        return []
    result = []
    for part in str(summary or "").split(", "):
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        key = key.strip()
        if not key or key == "...":
            continue
        result.append({
            "field_path": f"{path_prefix}.{key}",
            "payload_ref": payload_ref,
            "value_summary": value.strip(),
        })
    return result


def field_filter_from(filters, payload):
    field_path = (
        filters.get("field_path")
        or filters.get("fieldPath")
        or payload.get("field_path")
        or payload.get("fieldPath")
        or ""
    )
    has_field_value = any(key in filters for key in ("field_value", "fieldValue", "value")) or any(
        key in payload for key in ("field_value", "fieldValue")
    )
    field_value = filters.get("field_value", filters.get("fieldValue", filters.get("value")))
    if field_value is None and "field_value" in payload:
        field_value = payload.get("field_value")
    if field_value is None and "fieldValue" in payload:
        field_value = payload.get("fieldValue")
    return {
        "field_path": str(field_path or "").strip(),
        "has_field_value": has_field_value,
        "field_value": field_value,
    }


def matches_field_filter(row, field_filter):
    field_path = field_filter["field_path"]
    if not field_path:
        return True
    for payload_ref in payload_refs_for_field(row, field_path):
        fragment = payload_fragment_by_id(get_db(), payload_ref, field_path)
        if not fragment.get("ok"):
            continue
        if not field_filter["has_field_value"]:
            return True
        if values_equal(fragment.get("value"), field_filter["field_value"]):
            return True
    return False


def payload_refs_for_field(row, field_path):
    path = str(field_path or "")
    if path.startswith(("response.", "result.")):
        refs = [row.get("result_payload_id")]
    elif path.startswith(("request.", "parameters.", "params.")):
        refs = [row.get("params_payload_id")]
    else:
        refs = [row.get("params_payload_id"), row.get("result_payload_id")]
    return [ref for ref in refs if ref]


def values_equal(actual, expected):
    if actual == expected:
        return True
    if isinstance(actual, (int, float)) and isinstance(expected, (int, float)):
        return float(actual) == float(expected)
    return str(actual) == str(expected)


def differences(left, right):
    result = []
    for field in (
        "status",
        "breakpoint_rule_id",
        "request_summary",
        "response_summary",
        "exception_summary",
        "cost_ms",
        "request_payload_ref",
        "response_payload_ref",
    ):
        if str(left.get(field)) != str(right.get(field)):
            result.append({"field_path": field, "left": left.get(field), "right": right.get(field)})
    return result


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


def bool_value(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value or "").strip().lower() in ("1", "true", "yes", "on")
