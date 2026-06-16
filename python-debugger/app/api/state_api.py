import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from flask import Blueprint, current_app, jsonify, request

from app.services.debug_service import reset_debug, start_debug, state_response, stop_debug

state_api = Blueprint("state_api", __name__, url_prefix="/api")


@state_api.get("/debug/state")
def debug_state():
    return jsonify(state_response())


@state_api.post("/debug/start")
def start():
    switch_result = set_demo_debugger_enabled(True)
    if not switch_result["success"]:
        return jsonify(state_response(success=False, message=switch_result["message"])), 400
    result = start_debug(request.get_json(silent=True) or {})
    return jsonify(result), 200 if result.get("success") else 400


@state_api.post("/debug/stop")
def stop():
    released = stop_debug()
    switch_result = set_demo_debugger_enabled(False)
    success = switch_result["success"]
    return jsonify(
        state_response(
            success=success,
            releasedCount=released,
            message="调试已停止" if success else switch_result["message"],
        )
    ), 200 if success else 400


@state_api.post("/debug/reset")
def reset():
    return jsonify(reset_debug())


def set_demo_debugger_enabled(enabled):
    base_url = (current_app.config.get("DEMO_BASE_URL") or "").strip()
    if not base_url:
        return {"success": False, "message": "Java Demo 地址未配置"}
    url = base_url.rstrip("/") + "/api/demo/debugger/enabled"
    body = json.dumps({"enabled": enabled}).encode("utf-8")
    timeout = max(0.001, int(current_app.config.get("DEMO_REQUEST_TIMEOUT_MS", 1000)) / 1000)
    req = Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json;charset=UTF-8",
            "Accept": "application/json",
        },
    )
    try:
        with urlopen(req, timeout=timeout) as response:
            status = response.getcode()
            text = response.read().decode("utf-8", errors="replace")
    except HTTPError as exc:
        text = exc.read().decode("utf-8", errors="replace")
        return {
            "success": False,
            "message": f"Java Demo 调试开关请求失败：HTTP {exc.code}{response_suffix(text)}",
        }
    except (OSError, URLError) as exc:
        return {"success": False, "message": f"无法连接 Java Demo 调试开关：{exc}"}
    if status < 200 or status >= 300:
        return {
            "success": False,
            "message": f"Java Demo 调试开关请求失败：HTTP {status}{response_suffix(text)}",
        }
    return {"success": True}


def response_suffix(text):
    return "" if not text or not text.strip() else f"，响应：{text}"
