from flask import Blueprint, jsonify, request

from app.services.debug_service import declare_breakpoint_rule

agent_api = Blueprint("agent_api", __name__, url_prefix="/api/agent")


@agent_api.post("/breakpoints")
def declare_breakpoint():
    result = declare_breakpoint_rule(request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("ok") else 400
