from app.db.database import get_db, row_to_dict
from app.services.debug_service import breakpoint_slot_filter_key, condition_matches, normalize
from app.services.payload_store import payload_by_id, read_payload_value
from app.utils.json_utils import loads


def explain_breakpoint_match(rule_id, payload):
    interaction_id = payload.get("interaction_id") or payload.get("interactionId") or ""
    if not interaction_id:
        return error("invalid_request", rule_id, interaction_id, "interaction_id 不能为空。")
    rule = row("SELECT * FROM breakpoint WHERE id=?", rule_id)
    if not rule:
        return error("not_found", rule_id, interaction_id, "断点规则不存在。")
    interaction = row("SELECT * FROM call_record WHERE call_id=?", interaction_id)
    if not interaction:
        return error("not_found", rule_id, interaction_id, "交互记录不存在。")

    enabled = is_enabled(rule.get("enabled"))
    target_matched = rule.get("objectName") == interaction.get("objectName") and rule.get("cmdName") == interaction.get("cmdName")
    slot_filter_key = breakpoint_slot_filter_key(rule)
    interaction_slot_key = interaction.get("slotKey") or interaction.get("slot_key")
    slot_matched = slot_filter_key is None or str(slot_filter_key) == str(interaction_slot_key)
    match_mode = rule.get("matchMode") or rule.get("match_mode") or "command_only"
    condition_results = condition_result_list(rule, interaction) if match_mode == "params_condition" else []
    conditions_matched = all(item["matched"] for item in condition_results)
    matched = enabled and target_matched and slot_matched and conditions_matched
    return {
        "ok": True,
        "breakpoint_rule_id": rule_id,
        "interaction_id": interaction_id,
        "matched": matched,
        "facts": {
            "rule_enabled": enabled,
            "target_matched": target_matched,
            "slot_matched": slot_matched,
            "slot_filter_key": slot_filter_key,
            "interaction_slot_key": interaction_slot_key,
            "conditions_matched": conditions_matched,
            "match_mode": match_mode,
        },
        "condition_results": condition_results,
        "message": "该交互满足断点规则。" if matched else "该交互不满足断点规则。",
        "entities": [
            entity("breakpoint_rule", rule_id, f"{rule.get('objectName')}.{rule.get('cmdName')}", "armed" if enabled else "disabled"),
            entity("interaction", interaction_id, f"{interaction.get('objectName')}.{interaction.get('cmdName')}", interaction.get("status")),
        ],
    }


def condition_result_list(rule, interaction):
    params = payload_value(interaction.get("paramsPayloadId"))
    results = []
    for condition in rule.get("conditions") or loads(rule.get("conditions_json"), []):
        if not isinstance(condition, dict):
            continue
        path = str(condition.get("path") or "")
        operator = condition.get("operator") or condition.get("op") or "eq"
        expected = condition.get("value")
        found, actual = field_lookup(params, path)
        results.append({
            "path": path,
            "operator": operator,
            "expected": expected,
            "actual": actual,
            "actual_found": found,
            "matched": condition_matches(found, actual, operator, expected),
        })
    return results


def payload_value(payload_id):
    if not payload_id:
        return {}
    row = payload_by_id(get_db(), payload_id)
    return read_payload_value(row) or {}


def field_lookup(root, path):
    current = root
    for segment in field_segments(path):
        if isinstance(current, dict):
            if segment not in current:
                return False, None
            current = current[segment]
        elif isinstance(current, list):
            try:
                current = current[int(segment)]
            except (ValueError, IndexError):
                return False, None
        else:
            return False, None
    return True, current


def field_segments(path):
    text = str(path or "")
    for prefix in ("request.parameters.", "parameters.", "params."):
        if text.startswith(prefix):
            text = text[len(prefix):]
            break
    return [item for item in text.split(".") if item]


def row(sql, item_id):
    item = get_db().execute(sql, (item_id,)).fetchone()
    return normalize(row_to_dict(item)) if item else None


def is_enabled(value):
    if isinstance(value, str):
        return value.lower() not in ("", "0", "false")
    return bool(value)


def entity(entity_type, entity_id, label, status):
    return {"type": entity_type, "id": entity_id, "label": label, "status": status}


def error(status, rule_id, interaction_id, message):
    return {
        "ok": False,
        "status": status,
        "breakpoint_rule_id": rule_id,
        "interaction_id": interaction_id,
        "message": message,
        "entities": [],
    }
