from io import BytesIO
from pathlib import Path
import tempfile

from flask import Blueprint, jsonify, request, send_file

from app.services.debug_service import (
    clear_sessions,
    clear_current_session,
    create_session,
    delete_session,
    export_session_archive,
    export_session_archive_file,
    import_session_archive_file,
    import_session_archive,
    list_sessions,
    select_session,
)

session_api = Blueprint("session_api", __name__, url_prefix="/api/sessions")


@session_api.get("")
def sessions():
    return jsonify({"items": list_sessions()})


@session_api.delete("")
def clear_history_sessions():
    result = clear_sessions()
    return jsonify(result), 200 if result.get("success") else 400


@session_api.delete("/<session_id>")
def delete_history_session(session_id):
    result = delete_session(session_id)
    if result.get("success"):
        return jsonify(result)
    status = 404 if result.get("message") == "session not found" else 400
    return jsonify(result), status


@session_api.post("")
def create():
    return jsonify(create_session(request.get_json(silent=True) or {}))


@session_api.post("/<session_id>/select")
def select(session_id):
    result = select_session(session_id)
    return jsonify(result), 200 if result.get("success") else 404


@session_api.post("/<session_id>/export")
def export_session(session_id):
    result = export_session_archive(session_id, request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("success") else 404


@session_api.route("/<session_id>/export-file", methods=["GET", "POST"])
def export_session_file(session_id):
    result = export_session_archive_file(session_id, request.get_json(silent=True) or {})
    if not result.get("success"):
        return jsonify(result), 404
    path = Path(result["path"])
    filename = result.get("archiveName") or f"{session_id}.mbrec"
    if not filename.lower().endswith(".mbrec"):
        filename += ".mbrec"
    response = send_file(path, as_attachment=True, download_name=filename, mimetype="application/zip")
    response.call_on_close(lambda: _remove_file(path))
    return response


@session_api.post("/import")
def import_session():
    body = request.get_json(silent=True) or {}
    archive = body.get("archive") or body
    result = import_session_archive(archive, bool(body.get("lockInterfaces")), body.get("importFileName"))
    if result.get("success"):
        return jsonify(result)
    status = 409 if result.get("existingSessionId") else 400
    return jsonify(result), status


@session_api.post("/import-file")
def import_session_file():
    upload = request.files.get("file")
    lock_interfaces = _truthy(request.form.get("lockInterfaces"))
    if upload:
        temp = tempfile.NamedTemporaryFile(prefix="micro-breakpoint-import-", suffix=".mbrec", delete=False)
        temp_path = Path(temp.name)
        try:
            with temp:
                while True:
                    chunk = upload.stream.read(1024 * 1024)
                    if not chunk:
                        break
                    temp.write(chunk)
            with temp_path.open("rb") as handle:
                result = import_session_archive_file(handle, lock_interfaces, upload.filename)
        finally:
            try:
                temp_path.unlink()
            except OSError:
                pass
    else:
        result = import_session_archive_file(BytesIO(request.get_data()), _truthy(request.args.get("lockInterfaces")), request.args.get("importFileName"))
    if result.get("success"):
        return jsonify(result)
    status = 409 if result.get("existingSessionId") else 400
    return jsonify(result), status


def _truthy(value):
    return str(value or "").lower() in ("1", "true", "yes")


def _remove_file(path):
    try:
        path.unlink()
    except OSError:
        pass


@session_api.post("/current/clear")
def clear_current():
    result = clear_current_session()
    return jsonify(result), 200 if result.get("success") else 400
