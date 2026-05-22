from flask import Blueprint, jsonify, request

from app.services.debug_service import reset_debug, start_debug, state_response, stop_debug

state_api = Blueprint("state_api", __name__, url_prefix="/api")


@state_api.get("/debug/state")
def debug_state():
    return jsonify(state_response())


@state_api.post("/debug/start")
def start():
    result = start_debug(request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("success") else 400


@state_api.post("/debug/stop")
def stop():
    released = stop_debug()
    return jsonify(state_response(success=True, releasedCount=released))


@state_api.post("/debug/reset")
def reset():
    return jsonify(reset_debug())
