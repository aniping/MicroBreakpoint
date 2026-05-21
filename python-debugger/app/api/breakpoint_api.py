from flask import Blueprint, jsonify, request

from app.db.database import get_db
from app.services.core import create_breakpoint, list_breakpoints, update_breakpoint_interface_alias

bp_api = Blueprint("bp_api", __name__, url_prefix="/api/breakpoints")


@bp_api.get("")
def breakpoints():
    return jsonify({"items": list_breakpoints(request.args.get("sessionId"))})


@bp_api.post("")
def add_breakpoint():
    body = request.get_json() or {}
    return jsonify(create_breakpoint(body))


@bp_api.delete("/<breakpoint_id>")
def delete_breakpoint(breakpoint_id):
    get_db().execute("DELETE FROM breakpoint WHERE id=?", (breakpoint_id,))
    get_db().commit()
    return jsonify({"success": True})


@bp_api.patch("/<breakpoint_id>/alias")
def update_breakpoint_alias(breakpoint_id):
    body = request.get_json(silent=True) or {}
    result = update_breakpoint_interface_alias(breakpoint_id, body.get("alias", ""))
    return jsonify(result), 200 if result.get("success") else 404


@bp_api.post("/<breakpoint_id>/enable")
def enable_breakpoint(breakpoint_id):
    get_db().execute("UPDATE breakpoint SET enabled=1 WHERE id=?", (breakpoint_id,))
    get_db().commit()
    return jsonify({"success": True})


@bp_api.post("/<breakpoint_id>/disable")
def disable_breakpoint(breakpoint_id):
    get_db().execute("UPDATE breakpoint SET enabled=0 WHERE id=?", (breakpoint_id,))
    get_db().commit()
    return jsonify({"success": True})
