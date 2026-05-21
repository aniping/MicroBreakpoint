from flask import Blueprint, jsonify, request

from app.db.database import get_db, row_to_dict
from app.services.core import after_call, before_call, clear_call_records, create_breakpoint, list_calls, normalize
from app.services.wait_manager import wait_manager

call_api = Blueprint("call_api", __name__, url_prefix="/api/calls")


@call_api.post("/before")
def before():
    return jsonify(before_call(request.get_json() or {}))


@call_api.post("/after")
def after():
    return jsonify(after_call(request.get_json() or {}))


@call_api.get("")
def calls():
    return jsonify({"items": list_calls(request.args.get("sessionId"))})


@call_api.delete("")
def clear_calls():
    result = clear_call_records()
    return jsonify(result), 200 if result.get("success") else 400


@call_api.get("/<call_id>")
def call_detail(call_id):
    row = get_db().execute("SELECT * FROM call_record WHERE call_id=?", (call_id,)).fetchone()
    return jsonify(normalize(row_to_dict(row)) if row else {"success": False, "message": "not found"}), 200 if row else 404


@call_api.get("/<call_id>/wait")
def wait_call(call_id):
    action = wait_manager.wait(call_id)
    if action == "timeout_continue":
        get_db().execute("UPDATE call_record SET status='timeout' WHERE call_id=?", (call_id,))
        get_db().commit()
    return jsonify({"action": action})


@call_api.post("/<call_id>/continue")
def continue_call(call_id):
    released = wait_manager.continue_one(call_id)
    get_db().execute("UPDATE call_record SET status='continued' WHERE call_id=?", (call_id,))
    get_db().commit()
    return jsonify({"success": True, "released": released})


@call_api.post("/continue-all")
def continue_all():
    count = wait_manager.continue_all()
    get_db().execute("UPDATE call_record SET status='continued' WHERE status='paused'")
    get_db().commit()
    return jsonify({"success": True, "releasedCount": count})


@call_api.post("/<call_id>/breakpoint")
def breakpoint_from_call(call_id):
    row = get_db().execute("SELECT * FROM call_record WHERE call_id=?", (call_id,)).fetchone()
    if not row:
        return jsonify({"success": False, "message": "call not found"}), 404
    call = normalize(row_to_dict(row))
    body = request.get_json(silent=True) or {}
    selected = body.get("selectedArgs", [])
    condition = {k: call.get("args", {}).get(k) for k in selected if k in call.get("args", {})}
    return jsonify(create_breakpoint({
        "name": body.get("name") or f"{call['method_name']} args breakpoint",
        "enabled": body.get("enabled", True),
        "serviceName": call["service_name"],
        "className": call["class_name"],
        "methodName": call["method_name"],
        "displayName": call["display_name"],
        "condition": condition,
        "hitMode": body.get("hitMode", "always"),
        "sourceSessionId": call["session_id"],
        "sourceCallId": call_id,
    }))
