from flask import Blueprint, jsonify, request

from app.db.database import get_db, row_to_dict
from app.services.core import create_breakpoint, normalize

interface_api = Blueprint("interface_api", __name__, url_prefix="/api/interfaces")


@interface_api.get("")
def interfaces():
    rows = get_db().execute("SELECT * FROM discovered_interface ORDER BY last_seen_at DESC").fetchall()
    return jsonify({"items": [normalize(row_to_dict(row)) for row in rows]})


@interface_api.get("/<interface_id>")
def interface_detail(interface_id):
    row = get_db().execute("SELECT * FROM discovered_interface WHERE id=?", (interface_id,)).fetchone()
    return jsonify(normalize(row_to_dict(row)) if row else {"success": False, "message": "not found"}), 200 if row else 404


@interface_api.post("/<interface_id>/breakpoint")
def breakpoint_from_interface(interface_id):
    row = get_db().execute("SELECT * FROM discovered_interface WHERE id=?", (interface_id,)).fetchone()
    if not row:
        return jsonify({"success": False, "message": "interface not found"}), 404
    item = normalize(row_to_dict(row))
    body = request.get_json(silent=True) or {}
    return jsonify(create_breakpoint({
        "name": body.get("name") or f"{item['method_name']} breakpoint",
        "enabled": body.get("enabled", True),
        "serviceName": item["service_name"],
        "className": item["class_name"],
        "methodName": item["method_name"],
        "displayName": item["display_name"],
        "condition": {},
        "hitMode": body.get("hitMode", "always"),
        "sourceSessionId": item["session_id"],
        "sourceInterfaceId": interface_id,
    }))
