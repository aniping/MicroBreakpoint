from flask import Blueprint, jsonify, request

from app.db.database import get_db
from app.services.agent_breakpoint_service import (
    declare_breakpoint,
    delete_breakpoint_rule,
    get_breakpoint_rule,
    list_breakpoint_rules,
    set_breakpoint_rule_enabled,
)
from app.services.agent_paused_interaction_service import (
    continue_interaction,
    list_interactions,
    wait_paused_interaction,
)
from app.services.payload_store import payload_fragment_by_id

agent_api = Blueprint("agent_api", __name__, url_prefix="/api/agent")


@agent_api.post("/breakpoints")
def add_breakpoint():
    result = declare_breakpoint(request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("ok") else 400


@agent_api.get("/breakpoints")
def breakpoints():
    return jsonify(list_breakpoint_rules(request.args.get("sessionId")))


@agent_api.get("/breakpoints/<rule_id>")
def breakpoint(rule_id):
    result = get_breakpoint_rule(rule_id)
    return jsonify(result), 200 if result.get("ok") else 404


@agent_api.post("/breakpoints/<rule_id>/disable")
def disable_breakpoint(rule_id):
    result = set_breakpoint_rule_enabled(rule_id, False)
    return jsonify(result), 200 if result.get("ok") else 404


@agent_api.post("/breakpoints/<rule_id>/enable")
def enable_breakpoint(rule_id):
    result = set_breakpoint_rule_enabled(rule_id, True)
    return jsonify(result), 200 if result.get("ok") else 404


@agent_api.delete("/breakpoints/<rule_id>")
def delete_breakpoint(rule_id):
    result = delete_breakpoint_rule(rule_id)
    return jsonify(result), 200 if result.get("ok") else 404


@agent_api.post("/interactions/paused/search")
def paused_interactions():
    return jsonify(list_interactions(request.get_json(silent=True) or {}))


@agent_api.post("/interactions/wait-paused")
def wait_paused():
    result = wait_paused_interaction(request.get_json(silent=True) or {})
    return jsonify(result)


@agent_api.post("/interactions/<interaction_id>/continue")
def continue_paused(interaction_id):
    result = continue_interaction(interaction_id)
    return jsonify(result), 200 if result.get("ok") else 400


@agent_api.post("/payloads/fragment")
def payload_fragment():
    body = request.get_json(silent=True) or {}
    result = payload_fragment_by_id(
        get_db(),
        body.get("payload_ref") or body.get("payloadRef") or body.get("payload_id") or body.get("payloadId"),
        body.get("field_path") or body.get("fieldPath"),
    )
    status_code = 200 if result.get("ok") else 404 if result.get("status") == "not_found" else 400
    return jsonify(result), status_code
