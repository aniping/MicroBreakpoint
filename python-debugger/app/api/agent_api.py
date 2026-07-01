from flask import Blueprint, jsonify, request

from app.db.database import get_db
from app.services.debug_service import (
    continue_paused_interaction,
    declare_breakpoint_rule,
    list_paused_interactions,
)
from app.services.payload_store import payload_fragment_by_id

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
