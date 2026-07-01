import time

from app.services.debug_service import continue_paused_interaction, list_paused_interactions

DEFAULT_TIMEOUT_MS = 30_000
POLL_INTERVAL_SECONDS = 0.1


def list_interactions(payload):
    return list_paused_interactions(payload)


def continue_interaction(interaction_id):
    return continue_paused_interaction(interaction_id)


def wait_paused_interaction(payload):
    timeout_ms = max(0, int_or_default(payload.get("timeout_ms", payload.get("timeoutMs")), DEFAULT_TIMEOUT_MS))
    deadline = time.monotonic() + timeout_ms / 1000
    while True:
        listed = list_interactions(payload)
        interactions = listed.get("interactions") or []
        if interactions:
            item = interactions[0]
            return {
                "ok": True,
                "status": "paused",
                "breakpoint_rule_id": item.get("breakpoint_rule_id") or payload.get("breakpoint_rule_id") or "",
                "interaction_id": item.get("interaction_id"),
                "message": "目标调用已命中断点并暂停。",
                "entities": listed.get("entities") or [],
            }
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return {
                "ok": False,
                "status": "timeout",
                "breakpoint_rule_id": payload.get("breakpoint_rule_id") or "",
                "message": "等待超时，目标调用尚未命中断点。",
                "entities": [],
            }
        time.sleep(min(POLL_INTERVAL_SECONDS, remaining))


def int_or_default(value, default):
    try:
        return int(value if value is not None else default)
    except (TypeError, ValueError):
        return default
