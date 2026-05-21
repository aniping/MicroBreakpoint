from app import create_app
from app.utils.json_utils import dumps


def make_before(call_id="call-1", cmd="create", http_method="GET", request_uri="/api/demo/control", content_type=""):
    args = {"instType": "VNA", "cmdName": cmd, "slotId": 1, "params": {}}
    query_signature = dumps({"cmdName": [cmd], "instType": ["VNA"], "slotId": ["1"]}) if http_method == "GET" else ""
    return {
        "callId": call_id,
        "serviceName": "instrument-service-demo",
        "className": "com.example.instrumentdemo.service.InstrumentServiceImpl",
        "methodName": "instrumentControl",
        "httpMethod": http_method,
        "requestUri": request_uri,
        "querySignature": query_signature,
        "bodySignature": dumps(args),
        "contentType": content_type,
        "displayName": "仪表控制",
        "description": "通过槽位号转换 hid 号，操作对应仪器仪表实例",
        "threadName": "test",
        "timestamp": 1,
        "args": args,
        "parameterMeta": [{"name": "cmdName", "displayName": "仪表操作", "description": "仪表操作", "javaType": "java.lang.String"}],
    }


def test_record_discover_and_breakpoint_match(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    created = client.post("/api/session/create", json={}).get_json()
    assert created["mode"] == "idle"
    assert created["sessionId"].startswith("session-")
    start = client.post("/api/session/start-record", json={}).get_json()
    assert start["mode"] == "record"
    assert client.post("/api/calls/before", json=make_before()).get_json()["action"] == "continue"
    assert client.post("/api/calls/after", json={"callId": "call-1", "success": True, "costMs": 3, "result": {"ok": True}}).get_json()["success"]
    assert client.get("/api/interfaces").get_json()["items"][0]["method_name"] == "instrumentControl"

    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    assert client.post(f"/api/interfaces/{interface_id}/breakpoint", json={}).get_json()["success"]
    client.post("/api/session/stop-record")
    client.post("/api/session/start-debug", json={})

    paused = client.post("/api/calls/before", json=make_before("call-2")).get_json()
    assert paused["action"] == "pause"
    assert client.post("/api/calls/call-2/continue").get_json()["success"]


def test_record_requires_selected_session(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    response = client.post("/api/session/start-record", json={})

    assert response.status_code == 400
    assert response.get_json()["message"] == "请先新建或选择会话"


def test_debug_does_not_discover_new_interfaces(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    client.post("/api/session/create", json={})
    client.post("/api/session/start-debug", json={})
    payload = make_before("debug-new-method")
    payload["methodName"] = "newMethodOnlyInDebug"
    payload["displayName"] = "调试中新方法"

    assert client.post("/api/calls/before", json=payload).get_json()["action"] == "continue"

    assert client.get("/api/calls").get_json()["items"][0]["method_name"] == "newMethodOnlyInDebug"
    assert client.get("/api/interfaces").get_json()["items"] == []


def test_debug_does_not_update_existing_or_add_new_interfaces(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    client.post("/api/session/create", json={})
    client.post("/api/session/start-record", json={})
    client.post("/api/calls/before", json=make_before("record-create", cmd="create"))
    client.post("/api/calls/after", json={"callId": "record-create", "success": True, "costMs": 5, "result": {"ok": True}})

    before_debug = client.get("/api/interfaces").get_json()["items"]
    assert len(before_debug) == 1
    original = before_debug[0]
    assert original["call_count"] == 1
    assert original["success_count"] == 1

    client.post("/api/session/stop-record")
    client.post("/api/session/start-debug", json={})
    client.post("/api/calls/before", json=make_before("debug-same", cmd="create"))
    client.post("/api/calls/after", json={"callId": "debug-same", "success": True, "costMs": 7, "result": {"ok": True}})
    client.post("/api/calls/before", json=make_before("debug-new", cmd="stop", request_uri="/api/demo/control"))
    client.post("/api/calls/after", json={"callId": "debug-new", "success": True, "costMs": 9, "result": {"ok": True}})

    after_debug = client.get("/api/interfaces").get_json()["items"]
    assert len(after_debug) == 1
    assert after_debug[0]["id"] == original["id"]
    assert after_debug[0]["call_count"] == 1
    assert after_debug[0]["success_count"] == 1


def test_interface_identity_uses_http_signature(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    client.post("/api/session/create", json={})
    client.post("/api/session/start-record", json={})
    client.post("/api/calls/before", json=make_before("create-1", cmd="create"))
    client.post("/api/calls/after", json={"callId": "create-1", "success": True, "costMs": 5, "result": {"ok": True}})
    client.post("/api/calls/before", json=make_before("stop-1", cmd="stop"))
    client.post("/api/calls/after", json={"callId": "stop-1", "success": True, "costMs": 6, "result": {"ok": True}})
    client.post("/api/calls/before", json=make_before("create-2", cmd="create"))
    client.post("/api/calls/after", json={"callId": "create-2", "success": True, "costMs": 7, "result": {"ok": True}})

    items = client.get("/api/interfaces").get_json()["items"]
    assert len(items) == 2
    by_query = {item["query_signature"]: item for item in items}
    assert by_query[dumps({"cmdName": ["create"], "instType": ["VNA"], "slotId": ["1"]})]["call_count"] == 2
    assert by_query[dumps({"cmdName": ["stop"], "instType": ["VNA"], "slotId": ["1"]})]["call_count"] == 1


def test_clear_current_session_call_records(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    client.post("/api/session/create", json={})
    client.post("/api/session/start-record", json={})
    blocked = client.delete("/api/calls")
    assert blocked.status_code == 400
    assert blocked.get_json()["message"] == "请先停止记录或调试"
    client.post("/api/calls/before", json=make_before("call-to-clear"))
    client.post("/api/calls/after", json={"callId": "call-to-clear", "success": True, "costMs": 5, "result": {"ok": True}})
    client.post("/api/session/stop-record")

    cleared = client.delete("/api/calls")

    assert cleared.status_code == 200
    assert cleared.get_json()["deletedCount"] == 1
    assert client.get("/api/calls").get_json()["items"] == []
    assert len(client.get("/api/interfaces").get_json()["items"]) == 1


def test_clear_session_history_removes_related_data(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    client.post("/api/session/create", json={})
    client.post("/api/session/start-record", json={})
    client.post("/api/calls/before", json=make_before("history-call"))
    client.post("/api/calls/after", json={"callId": "history-call", "success": True, "costMs": 5, "result": {"ok": True}})
    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    assert client.post(f"/api/interfaces/{interface_id}/breakpoint", json={}).get_json()["success"]
    client.post("/api/session/stop-record")

    cleared = client.delete("/api/session")

    assert cleared.status_code == 200
    assert cleared.get_json()["deletedCount"]["sessions"] == 1
    assert client.get("/api/session").get_json()["items"] == []
    assert client.get("/api/calls").get_json()["items"] == []
    assert client.get("/api/interfaces").get_json()["items"] == []
    assert client.get("/api/breakpoints").get_json()["items"] == []
    assert client.get("/api/debug/state").get_json()["hasSession"] is False
