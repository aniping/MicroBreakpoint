from flask import Blueprint, jsonify, request

from app.services.debug_service import (
    clear_current_session,
    create_session,
    delete_session,
    list_sessions,
    select_session,
)

session_api = Blueprint("session_api", __name__, url_prefix="/api/sessions")


@session_api.get("")
def sessions():
    return jsonify({"items": list_sessions()})


@session_api.delete("/<session_id>")
def delete_history_session(session_id):
    result = delete_session(session_id)
    if result.get("success"):
        return jsonify(result)
    status = 404 if result.get("message") == "session not found" else 400
    return jsonify(result), status


@session_api.post("")
def create():
    return jsonify(create_session(request.get_json(silent=True) or {}))


@session_api.post("/<session_id>/select")
def select(session_id):
    result = select_session(session_id)
    return jsonify(result), 200 if result.get("success") else 404


@session_api.post("/current/clear")
def clear_current():
    result = clear_current_session()
    return jsonify(result), 200 if result.get("success") else 400
