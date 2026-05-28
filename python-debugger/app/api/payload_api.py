from flask import Blueprint, Response, jsonify, request, send_file

from app.db.database import get_db
from app.services.payload_store import (
    export_payload_by_id,
    payload_chunk_by_id,
    search_payload_by_id,
)

payload_api = Blueprint("payload_api", __name__, url_prefix="/api/payloads")


@payload_api.get("/<payload_id>")
def payload(payload_id):
    item = payload_chunk_by_id(
        get_db(),
        payload_id,
        request.args.get("offset", 0),
        request.args.get("limit", 1048576),
    )
    return jsonify(item if item else {"success": False, "message": "payload not found"}), 200 if item else 404


@payload_api.get("/<payload_id>/export")
def export_payload(payload_id):
    row, target = export_payload_by_id(get_db(), payload_id)
    if not row or not target:
        return jsonify({"success": False, "message": "payload not found"}), 404
    payload_type = row["payload_type"] or "payload"
    filename = f"{payload_type}.json" if (row["content_format"] or "json") == "json" else f"{payload_type}.txt"
    if hasattr(target, "exists"):
        return send_file(target, as_attachment=True, download_name=filename)
    return Response(
        row["content_text"] or "",
        mimetype="application/json" if filename.endswith(".json") else "text/plain",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@payload_api.get("/<payload_id>/search")
def search_payload(payload_id):
    item = search_payload_by_id(get_db(), payload_id, request.args.get("q", ""))
    return jsonify(item if item else {"success": False, "message": "payload not found"}), 200 if item else 404
