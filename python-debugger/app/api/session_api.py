from flask import Blueprint, jsonify, request

from app.services.core import start_session, stop_session, state_response

session_api = Blueprint("session_api", __name__, url_prefix="/api/session")


@session_api.post("/start-record")
def start_record():
    return jsonify(start_session("record", request.get_json(silent=True) or {}))


@session_api.post("/stop-record")
def stop_record():
    stop_session()
    return jsonify(state_response(success=True))


@session_api.post("/start-debug")
def start_debug():
    return jsonify(start_session("debug", request.get_json(silent=True) or {}))


@session_api.post("/stop-debug")
def stop_debug():
    released = stop_session()
    return jsonify(state_response(success=True, releasedCount=released))
