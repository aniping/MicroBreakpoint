from flask import Blueprint, jsonify, request

from app.services.core import clear_sessions, create_session, list_sessions, select_session, start_session, stop_activity, state_response

session_api = Blueprint("session_api", __name__, url_prefix="/api/session")


@session_api.get("")
def sessions():
    return jsonify({"items": list_sessions()})


@session_api.delete("")
def clear_history():
    result = clear_sessions()
    return jsonify(result), 200 if result.get("success") else 400


@session_api.post("/create")
def create():
    return jsonify(create_session(request.get_json(silent=True) or {}))


@session_api.post("/<session_id>/select")
def select(session_id):
    result = select_session(session_id)
    return jsonify(result), 200 if result.get("success") else 404


@session_api.post("/start-record")
def start_record():
    result = start_session("record", request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("success") else 400


@session_api.post("/stop-record")
def stop_record():
    stop_activity()
    return jsonify(state_response(success=True))


@session_api.post("/start-debug")
def start_debug():
    result = start_session("debug", request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("success") else 400


@session_api.post("/stop-debug")
def stop_debug():
    released = stop_activity()
    return jsonify(state_response(success=True, releasedCount=released))
