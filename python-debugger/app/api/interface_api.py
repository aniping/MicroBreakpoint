from flask import Blueprint, jsonify, request

from app.db.database import get_db, row_to_dict
from app.services.debug_service import (
    breakpoint_from_interface as create_breakpoint_from_interface,
    grouped_interfaces,
    set_interface_locked,
    list_interfaces,
    normalize,
    state_response,
    update_interface_alias,
)

interface_api = Blueprint("interface_api", __name__, url_prefix="/api/interfaces")


@interface_api.get("")
def interfaces():
    return jsonify({
        "items": list_interfaces(
            request.args.get("sessionId"),
            request.args.get("objectName"),
            request.args.get("keyword"),
            request.args.get("status"),
            request.args.get("sortBy"),
            request.args.get("sortOrder"),
        )
    })


@interface_api.get("/grouped")
def interfaces_grouped():
    return jsonify({"success": True, "groups": grouped_interfaces(request.args.get("sessionId"))})


@interface_api.get("/lock")
def interface_lock_state():
    return jsonify(state_response())


@interface_api.post("/lock")
def update_interface_lock():
    body = request.get_json(silent=True) or {}
    result = set_interface_locked(bool(body.get("locked")))
    return jsonify(result)


@interface_api.get("/<interface_id>")
def interface_detail(interface_id):
    row = get_db().execute("SELECT * FROM discovered_interface WHERE id=?", (interface_id,)).fetchone()
    if not row:
        return jsonify({"success": False, "message": "not found"}), 404
    item = normalize(row_to_dict(row))
    samples = get_db().execute(
        """SELECT * FROM interface_param_sample
           WHERE interface_id=?
           ORDER BY last_seen_at DESC, created_at DESC
           LIMIT 50""",
        (interface_id,),
    ).fetchall()
    item["samples"] = [normalize(row_to_dict(sample)) for sample in samples]
    return jsonify(item)


@interface_api.patch("/<interface_id>/alias")
def update_alias(interface_id):
    body = request.get_json(silent=True) or {}
    result = update_interface_alias(interface_id, body.get("alias", ""))
    return jsonify(result), 200 if result.get("success") else 404


@interface_api.post("/<interface_id>/breakpoint")
def breakpoint_from_interface(interface_id):
    body = request.get_json(silent=True) or {}
    result = create_breakpoint_from_interface(interface_id, body)
    return jsonify(result), 200 if result.get("success") else 404
