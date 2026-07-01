from app.db.database import get_db
from app.services.debug_service import declare_breakpoint_rule, list_breakpoints, normalize, row_to_dict
from app.utils.json_utils import loads
from app.utils.time_utils import now_iso


def declare_breakpoint(payload):
    return declare_breakpoint_rule(payload)


def list_breakpoint_rules(session_id=None):
    rules = [agent_rule(row) for row in list_breakpoints(session_id)]
    return {
        "ok": True,
        "breakpoint_rules": rules,
        "entities": [entity(rule) for rule in rules],
    }


def get_breakpoint_rule(rule_id):
    row = breakpoint_row(rule_id)
    if not row:
        return error("not_found", rule_id, "断点规则不存在。")
    return response(agent_rule(row), "断点规则已读取。")


def set_breakpoint_rule_enabled(rule_id, enabled):
    if not breakpoint_row(rule_id):
        return error("not_found", rule_id, "断点规则不存在。")
    db = get_db()
    db.execute(
        "UPDATE breakpoint SET enabled=?, updated_at=? WHERE id=?",
        (1 if enabled else 0, now_iso(), rule_id),
    )
    db.commit()
    return response(agent_rule(breakpoint_row(rule_id)), "断点规则已启用。" if enabled else "断点规则已禁用。")


def delete_breakpoint_rule(rule_id):
    row = breakpoint_row(rule_id)
    if not row:
        return error("not_found", rule_id, "断点规则不存在。")
    rule = agent_rule(row)
    get_db().execute("DELETE FROM breakpoint WHERE id=?", (rule_id,))
    get_db().commit()
    rule["status"] = "cancelled"
    return response(rule, "断点规则已取消。")


def breakpoint_row(rule_id):
    row = get_db().execute("SELECT * FROM breakpoint WHERE id=?", (rule_id,)).fetchone()
    if not row:
        return None
    return normalize(row_to_dict(row))


def agent_rule(row):
    object_name = row.get("objectName") or row.get("object_name") or ""
    cmd_name = row.get("cmdName") or row.get("cmd_name") or ""
    display_name = row.get("displayName") or row.get("display_name") or ""
    match_mode = row.get("matchMode") or row.get("match_mode") or "command_only"
    match = {
        "type": "parameters" if match_mode == "params_condition" else "interface",
        "mode": match_mode,
    }
    if match_mode == "params_condition":
        match["conditions"] = row.get("conditions") or loads(row.get("conditions_json"), [])
    return {
        "breakpoint_rule_id": row.get("id"),
        "label": display_name or f"{object_name}.{cmd_name}",
        "status": "armed" if is_enabled(row.get("enabled")) else "disabled",
        "target": {
            "object": object_name,
            "command": cmd_name,
            "display_name": display_name,
            "session_id": row.get("sessionId") or row.get("session_id"),
        },
        "match": match,
        "hit_count": row.get("hitCount", row.get("hit_count", 0)),
        "source_type": row.get("sourceType") or row.get("source_type"),
        "created_at": row.get("createdAt") or row.get("created_at"),
        "updated_at": row.get("updatedAt") or row.get("updated_at"),
    }


def response(rule, message):
    result = dict(rule)
    result["ok"] = True
    result["message"] = message
    result["entities"] = [entity(rule)]
    return result


def entity(rule):
    return {
        "type": "breakpoint_rule",
        "id": rule["breakpoint_rule_id"],
        "label": rule["label"],
        "status": rule["status"],
    }


def error(status, rule_id, message):
    return {
        "ok": False,
        "status": status,
        "breakpoint_rule_id": rule_id,
        "message": message,
        "entities": [],
    }


def is_enabled(value):
    if isinstance(value, str):
        return value.lower() not in ("", "0", "false")
    return bool(value)
