from flask import Blueprint, jsonify, request

from app.db.database import get_db
from app.utils.time_utils import now_iso
from app.services.debug_service import create_breakpoint, list_breakpoints

bp_api = Blueprint("bp_api", __name__, url_prefix="/api/breakpoints")


@bp_api.get("")
def breakpoints():
    return jsonify({"items": list_breakpoints(request.args.get("sessionId"))})


@bp_api.post("")
def add_breakpoint():
    body = request.get_json() or {}
    result = create_breakpoint(body)
    return jsonify(result), 200 if result.get("success") else (409 if result.get("code", "").startswith("DUPLICATE_") else 400)


@bp_api.delete("/<breakpoint_id>")
def delete_breakpoint(breakpoint_id):
    get_db().execute("DELETE FROM breakpoint WHERE id=?", (breakpoint_id,))
    get_db().commit()
    return jsonify({"success": True})


@bp_api.post("/<breakpoint_id>/enable")
def enable_breakpoint(breakpoint_id):
    get_db().execute("UPDATE breakpoint SET enabled=1, updated_at=? WHERE id=?", (now_iso(), breakpoint_id))
    get_db().commit()
    return jsonify({"success": True})


@bp_api.post("/<breakpoint_id>/disable")
def disable_breakpoint(breakpoint_id):
    get_db().execute("UPDATE breakpoint SET enabled=0, updated_at=? WHERE id=?", (now_iso(), breakpoint_id))
    get_db().commit()
    return jsonify({"success": True})
