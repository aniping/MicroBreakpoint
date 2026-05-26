from flask import Blueprint, jsonify, request

from app.db.database import get_db, row_to_dict
from app.services.debug_service import (
    after_call,
    before_call,
    breakpoint_from_call as create_breakpoint_from_call,
    continue_all_calls,
    continue_call as continue_one_call,
    grouped_calls,
    list_calls,
    normalize,
    register_interface_from_call,
)
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
    return jsonify({
        "items": list_calls(
            request.args.get("sessionId"),
            request.args.get("objectName"),
            request.args.get("keyword"),
            request.args.get("status"),
            request.args.get("sortBy"),
            request.args.get("sortOrder"),
        )
    })


@call_api.get("/grouped")
def calls_grouped():
    return jsonify({"success": True, "groups": grouped_calls(request.args.get("sessionId"))})


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
    return jsonify(continue_one_call(call_id))


@call_api.post("/<call_id>/interface")
def register_interface(call_id):
    result = register_interface_from_call(call_id)
    return jsonify(result), 200 if result.get("success") else 404


@call_api.post("/continue-all")
def continue_all():
    return jsonify(continue_all_calls())


@call_api.post("/<call_id>/breakpoint")
def breakpoint_from_call(call_id):
    body = request.get_json(silent=True) or {}
    result = create_breakpoint_from_call(call_id, body)
    return jsonify(result), 200 if result.get("success") else 404
