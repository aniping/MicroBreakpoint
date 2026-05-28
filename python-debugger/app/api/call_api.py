from flask import Blueprint, Response, jsonify, request, send_file

from app.db.database import get_db, row_to_dict
from app.services.debug_service import (
    after_call,
    before_call,
    breakpoint_from_call as create_breakpoint_from_call,
    call_detail as call_detail_payload,
    continue_all_calls,
    continue_call as continue_one_call,
    export_payload_target,
    grouped_calls,
    list_calls,
    normalize,
    payload_chunk,
    register_interface_from_call,
    search_payload,
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
    return jsonify(list_calls(
        request.args.get("sessionId"),
        request.args.get("objectName"),
        request.args.get("keyword"),
        request.args.get("status"),
        request.args.get("sortBy"),
        request.args.get("sortOrder"),
        request.args.get("page"),
        request.args.get("pageSize"),
    ))


@call_api.get("/grouped")
def calls_grouped():
    return jsonify({"success": True, "groups": grouped_calls(request.args.get("sessionId"))})


@call_api.get("/<call_id>")
def call_detail(call_id):
    item = call_detail_payload(call_id)
    return jsonify(item if item else {"success": False, "message": "not found"}), 200 if item else 404


@call_api.get("/<call_id>/payload")
def call_payload(call_id):
    item = payload_chunk(
        get_db(),
        call_id,
        request.args.get("type", "params"),
        request.args.get("offset", 0),
        request.args.get("limit", 8192),
    )
    return jsonify(item if item else {"success": False, "message": "payload not found"}), 200 if item else 404


@call_api.get("/<call_id>/payload/export")
def export_call_payload(call_id):
    payload_type = request.args.get("type", "params")
    row, target = export_payload_target(get_db(), call_id, payload_type)
    if not row or not target:
        return jsonify({"success": False, "message": "payload not found"}), 404
    filename = f"{payload_type}.json" if (row["content_format"] or "json") == "json" else f"{payload_type}.txt"
    if hasattr(target, "exists"):
        return send_file(target, as_attachment=True, download_name=filename)
    return Response(
        row["content_text"] or "",
        mimetype="application/json" if filename.endswith(".json") else "text/plain",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@call_api.get("/<call_id>/payload/search")
def search_call_payload(call_id):
    item = search_payload(get_db(), call_id, request.args.get("type", "params"), request.args.get("q", ""))
    return jsonify(item if item else {"success": False, "message": "payload not found"}), 200 if item else 404


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
    if result.get("success"):
        return jsonify(result)
    status = 409 if result.get("code", "").startswith("DUPLICATE_") else 404
    return jsonify(result), status
