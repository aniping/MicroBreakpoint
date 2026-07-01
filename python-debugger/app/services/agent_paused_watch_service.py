import time
import uuid
from threading import Lock

from app.utils.time_utils import now_iso

DEFAULT_EXPIRES_IN_MS = 300_000
MAX_EVENTS = 200

_lock = Lock()
_watches = {}
_events = []
_event_sequence = 0


def watch_paused_interaction(payload):
    with _lock:
        cleanup_expired()
        target = payload.get("target") if isinstance(payload.get("target"), dict) else {}
        rule_id = str(payload.get("breakpoint_rule_id") or "")
        object_name = str(target.get("object") or target.get("objectName") or "")
        cmd_name = str(target.get("command") or target.get("cmdName") or "")
        if not (rule_id or object_name or cmd_name):
            return error("invalid_request", "", "breakpoint_rule_id 或 target 不能为空。")
        watch_id = f"watch-{uuid.uuid4().hex[:12]}"
        label = watch_label(object_name, cmd_name, rule_id)
        expires_in_ms = max(1, int_or_default(payload.get("expires_in_ms", payload.get("expiresInMs")), DEFAULT_EXPIRES_IN_MS))
        _watches[watch_id] = {
            "watch_id": watch_id,
            "breakpoint_rule_id": rule_id,
            "object_name": object_name,
            "cmd_name": cmd_name,
            "label": label,
            "expires_at": time.time() + expires_in_ms / 1000,
        }
        return {
            "ok": True,
            "status": "watching",
            "watch_id": watch_id,
            "message": f"已开始等待 {label} 命中断点；命中后会提醒。",
            "entities": [entity("paused_interaction_watch", watch_id, label, "watching")],
        }


def cancel_paused_interaction_watch(watch_id):
    with _lock:
        watch = _watches.pop(watch_id, None)
        if not watch:
            return error("not_found", watch_id, "暂停提醒不存在。")
        return {
            "ok": True,
            "status": "cancelled",
            "watch_id": watch_id,
            "message": "暂停提醒已取消；断点规则不受影响。",
            "entities": [entity("paused_interaction_watch", watch_id, watch["label"], "cancelled")],
        }


def list_agent_events(watch_id=None, after_event_id=None):
    with _lock:
        cleanup_expired()
        after_sequence = event_sequence(after_event_id)
        items = [
            item for item in _events
            if (not watch_id or item.get("watch_id") == watch_id) and item.get("sequence", 0) > after_sequence
        ]
        return {"ok": True, "events": items, "entities": event_entities(items)}


def record_paused_interaction(breakpoint_rule_id, object_name, cmd_name, interaction_id):
    global _event_sequence
    with _lock:
        cleanup_expired()
        matched = [
            watch for watch in _watches.values()
            if watch_matches(watch, breakpoint_rule_id, object_name, cmd_name)
        ]
        if not matched:
            _event_sequence += 1
            _events.append(paused_event(_event_sequence, None, breakpoint_rule_id, object_name, cmd_name, interaction_id))
        for watch in matched:
            _event_sequence += 1
            event = paused_event(_event_sequence, watch, breakpoint_rule_id, object_name, cmd_name, interaction_id)
            _events.append(event)
            _watches.pop(watch["watch_id"], None)
        trim_events()


def paused_event(sequence, watch, breakpoint_rule_id, object_name, cmd_name, interaction_id):
    label = watch_label(object_name, cmd_name, breakpoint_rule_id)
    entities = []
    if breakpoint_rule_id:
        entities.append(entity("breakpoint_rule", breakpoint_rule_id, label, "armed"))
    if watch:
        entities.append(entity("paused_interaction_watch", watch["watch_id"], watch["label"], "triggered"))
    entities.append(entity("interaction", interaction_id, label, "paused"))
    event = {
        "sequence": sequence,
        "event_id": f"evt-{sequence}",
        "event": "interaction_paused",
        "breakpoint_rule_id": breakpoint_rule_id,
        "interaction_id": interaction_id,
        "created_at": now_iso(),
        "entities": entities,
    }
    if watch:
        event["watch_id"] = watch["watch_id"]
    return event


def event_entities(events):
    result = []
    seen = set()
    for event in events:
        for item in event.get("entities") or []:
            key = (item.get("type"), item.get("id"))
            if key in seen:
                continue
            seen.add(key)
            result.append(item)
    return result


def watch_matches(watch, rule_id, object_name, cmd_name):
    if watch["breakpoint_rule_id"] and watch["breakpoint_rule_id"] == rule_id:
        return True
    object_matches = not watch["object_name"] or watch["object_name"] == object_name
    command_matches = not watch["cmd_name"] or watch["cmd_name"] == cmd_name
    return object_matches and command_matches


def cleanup_expired():
    now = time.time()
    for watch_id, watch in list(_watches.items()):
        if watch["expires_at"] < now:
            _watches.pop(watch_id, None)


def trim_events():
    if len(_events) > MAX_EVENTS:
        del _events[:len(_events) - MAX_EVENTS]


def event_sequence(event_id):
    try:
        return int(str(event_id or "").replace("evt-", ""))
    except ValueError:
        return 0


def watch_label(object_name, cmd_name, fallback):
    if object_name or cmd_name:
        return f"{object_name}.{cmd_name}"
    return fallback


def entity(entity_type, entity_id, label, status):
    return {"type": entity_type, "id": entity_id, "label": label, "status": status}


def error(status, watch_id, message):
    return {"ok": False, "status": status, "watch_id": watch_id, "message": message, "entities": []}


def int_or_default(value, default):
    try:
        return int(value if value is not None else default)
    except (TypeError, ValueError):
        return default
