from flask import Blueprint, jsonify, request

from app.services.debug_service import (
    continue_paused_interaction,
    declare_breakpoint_rule,
    list_paused_interactions,
)

agent_api = Blueprint("agent_api", __name__, url_prefix="/api/agent")


@agent_api.post("/breakpoints")
def declare_breakpoint():
    result = declare_breakpoint_rule(request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("ok") else 400


@agent_api.post("/interactions/paused/search")
def paused_interactions():
    return jsonify(list_paused_interactions(request.get_json(silent=True) or {}))


@agent_api.post("/interactions/<interaction_id>/continue")
def continue_interaction(interaction_id):
    result = continue_paused_interaction(interaction_id)
    return jsonify(result), 200 if result.get("ok") else 400
