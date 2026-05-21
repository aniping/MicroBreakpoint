from app import create_app


def make_before(call_id="call-1", cmd="create"):
    return {
        "callId": call_id,
        "serviceName": "instrument-service-demo",
        "className": "com.example.instrumentdemo.service.InstrumentServiceImpl",
        "methodName": "instrumentControl",
        "displayName": "仪表控制",
        "description": "通过槽位号转换 hid 号，操作对应仪器仪表实例",
        "threadName": "test",
        "timestamp": 1,
        "args": {"instType": "VNA", "cmdName": cmd, "slotId": 1, "params": {}},
        "parameterMeta": [{"name": "cmdName", "displayName": "仪表操作", "description": "仪表操作", "javaType": "java.lang.String"}],
    }


def test_record_discover_and_breakpoint_match(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

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
