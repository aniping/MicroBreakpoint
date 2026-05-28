from flask import Blueprint, jsonify, request

from app.db.database import get_db, row_to_dict
from app.services.debug_service import (
    breakpoint_from_interface as create_breakpoint_from_interface,
    grouped_interfaces,
    list_interface_breakpoints,
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
            request.args.get("page"),
            request.args.get("pageSize"),
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
    row = get_db().execute(
        """SELECT id, session_id, object_name, cmd_name, slot_id, slot_key, service_name,
                  class_name, method_name, interface_alias, display_name, description,
                  latest_params_fingerprint, params_sample_count, params_summary,
                  first_seen_at, last_seen_at, call_count, success_count, exception_count,
                  avg_cost_ms, max_cost_ms, min_cost_ms, created_at, updated_at
           FROM discovered_interface
           WHERE id=?""",
        (interface_id,),
    ).fetchone()
    if not row:
        return jsonify({"success": False, "message": "not found"}), 404
    item = normalize(row_to_dict(row))
    samples = get_db().execute(
        """SELECT s.id, s.interface_id, s.call_id, s.object_name, s.cmd_name, s.slot_id, s.slot_key,
                  s.params_fingerprint, s.params_hash, s.params_summary, s.params_size, s.params_payload_id,
                  c.params_preview, c.params_truncated,
                  s.result_summary, s.result_size, s.result_payload_id, s.success, s.cost_ms,
                  s.first_seen_at, s.last_seen_at, s.created_at, s.updated_at, s.seen_count
           FROM interface_param_sample s
           LEFT JOIN call_record c ON s.call_id=c.call_id
           WHERE s.interface_id=?
           ORDER BY s.last_seen_at DESC, s.created_at DESC
           LIMIT 10""",
        (interface_id,),
    ).fetchall()
    item["samples"] = [normalize(row_to_dict(sample)) for sample in samples]
    return jsonify(item)


@interface_api.get("/<interface_id>/samples")
def interface_samples(interface_id):
    limit = request.args.get("limit", 10)
    offset = request.args.get("offset", 0)
    try:
        limit = min(max(int(limit), 1), 50)
        offset = max(int(offset), 0)
    except (TypeError, ValueError):
        limit = 10
        offset = 0
    rows = get_db().execute(
        """SELECT s.id, s.interface_id, s.call_id, s.object_name, s.cmd_name, s.slot_id, s.slot_key,
                  s.params_fingerprint, s.params_hash, s.params_summary, s.params_size, s.params_payload_id,
                  c.params_preview, c.params_truncated,
                  s.result_summary, s.result_size, s.result_payload_id, s.success, s.cost_ms,
                  s.first_seen_at, s.last_seen_at, s.created_at, s.updated_at, s.seen_count
           FROM interface_param_sample s
           LEFT JOIN call_record c ON s.call_id=c.call_id
           WHERE s.interface_id=?
           ORDER BY s.last_seen_at DESC, s.created_at DESC
           LIMIT ? OFFSET ?""",
        (interface_id, limit, offset),
    ).fetchall()
    return jsonify({"success": True, "items": [normalize(row_to_dict(row)) for row in rows], "limit": limit, "offset": offset})


@interface_api.get("/<interface_id>/breakpoints")
def interface_breakpoints(interface_id):
    items = list_interface_breakpoints(interface_id)
    if items is None:
        return jsonify({"success": False, "message": "not found"}), 404
    return jsonify({"success": True, "items": items})


@interface_api.patch("/<interface_id>/alias")
def update_alias(interface_id):
    body = request.get_json(silent=True) or {}
    result = update_interface_alias(interface_id, body.get("alias", ""))
    return jsonify(result), 200 if result.get("success") else 404


@interface_api.post("/<interface_id>/breakpoint")
def breakpoint_from_interface(interface_id):
    body = request.get_json(silent=True) or {}
    result = create_breakpoint_from_interface(interface_id, body)
    if result.get("success"):
        return jsonify(result)
    status = 409 if result.get("code", "").startswith("DUPLICATE_") else 404
    return jsonify(result), status
