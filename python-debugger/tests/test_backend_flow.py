from app import create_app


def make_before(call_id="call-1", object_name="SA", cmd="start", slot_id=1, params=None):
    params = params if params is not None else {}
    return {
        "callId": call_id,
        "objectName": object_name,
        "cmdName": cmd,
        "slotId": slot_id,
        "description": f"{object_name} {cmd}",
        "params": params,
        "serviceName": "instrument-service-demo",
        "className": "com.example.instrumentdemo.service.InstrumentServiceImpl",
        "methodName": "instrumentControl",
        "displayName": "仪表控制",
        "threadName": "test",
        "rawArgs": {"instType": object_name, "cmdName": cmd, "slotId": slot_id, "params": params},
        "parameterMeta": [{"name": "params", "displayName": "操作传参", "javaType": "java.util.Map"}],
    }


def make_client(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    return app.test_client()


def create_and_start(client):
    created = client.post("/api/sessions", json={}).get_json()
    started = client.post("/api/debug/start", json={}).get_json()
    return created["sessionId"], started


def finish(client, call_id, success=True, cost_ms=5):
    return client.post(
        "/api/calls/after",
        json={"callId": call_id, "success": success, "costMs": cost_ms, "result": {"ok": success}},
    ).get_json()


def test_non_debug_reports_are_ignored(tmp_path):
    client = make_client(tmp_path)

    assert client.post("/api/calls/before", json=make_before()).get_json()["action"] == "continue"
    assert finish(client, "call-1")["ignored"] is True

    state = client.get("/api/debug/state").get_json()
    assert state["state"] == "NO_SESSION"
    assert state["callCount"] == 0
    assert client.get("/api/calls").get_json()["items"] == []
    assert client.get("/api/interfaces").get_json()["items"] == []


def test_debug_records_and_discovers_by_business_identity(tmp_path):
    client = make_client(tmp_path)

    session_id, started = create_and_start(client)
    assert started["state"] == "DEBUGGING"
    assert started["debugging"] is True

    client.post("/api/calls/before", json=make_before("call-a", cmd="start", params={"mode": "A"}))
    finish(client, "call-a", cost_ms=8)
    client.post("/api/calls/before", json=make_before("call-b", cmd="start", params={"mode": "B"}))
    finish(client, "call-b", cost_ms=12)
    client.post("/api/calls/before", json=make_before("call-c", cmd="stop", params={"mode": "A"}))
    finish(client, "call-c", cost_ms=4)

    calls = client.get("/api/calls").get_json()["items"]
    assert len(calls) == 3
    assert {item["object_name"] for item in calls} == {"SA"}
    assert {item["cmd_name"] for item in calls} == {"start", "stop"}
    assert calls[0]["params"] == {"mode": "A"}

    interfaces = client.get("/api/interfaces").get_json()["items"]
    by_cmd = {item["cmd_name"]: item for item in interfaces}
    assert set(by_cmd) == {"start", "stop"}
    assert by_cmd["start"]["session_id"] == session_id
    assert by_cmd["start"]["call_count"] == 2
    assert by_cmd["start"]["params_sample_count"] == 2
    assert by_cmd["stop"]["call_count"] == 1


def test_stop_then_restart_same_session_appends_data(tmp_path):
    client = make_client(tmp_path)

    session_id, _ = create_and_start(client)
    client.post("/api/calls/before", json=make_before("first", cmd="start"))
    finish(client, "first")
    assert client.post("/api/debug/stop").get_json()["debugging"] is False

    assert client.post("/api/calls/before", json=make_before("ignored", cmd="middle")).get_json()["action"] == "continue"
    finish(client, "ignored")
    assert len(client.get("/api/calls").get_json()["items"]) == 1

    client.post("/api/debug/start", json={})
    client.post("/api/calls/before", json=make_before("second", cmd="stop"))
    finish(client, "second")

    calls = client.get("/api/calls").get_json()["items"]
    assert len(calls) == 2
    assert {item["session_id"] for item in calls} == {session_id}
    assert [item["call_index"] for item in sorted(calls, key=lambda item: item["call_index"])] == [1, 2]


def test_after_call_updates_existing_record_even_after_stop(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("late-after", cmd="start"))
    client.post("/api/debug/stop")
    assert finish(client, "late-after", cost_ms=19)["success"] is True

    call = client.get("/api/calls").get_json()["items"][0]
    assert call["status"] == "finished"
    assert call["cost_ms"] == 19


def test_slot_null_uses_stable_unique_key(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("null-1", slot_id=None, params={"a": 1}))
    finish(client, "null-1")
    client.post("/api/calls/before", json=make_before("null-2", slot_id=None, params={"a": 2}))
    finish(client, "null-2")

    interfaces = client.get("/api/interfaces").get_json()["items"]
    assert len(interfaces) == 1
    assert interfaces[0]["slot_id"] is None
    assert interfaces[0]["slot_key"] == "__NULL__"
    assert interfaces[0]["call_count"] == 2
    assert interfaces[0]["params_sample_count"] == 2


def test_breakpoints_are_session_scoped(tmp_path):
    client = make_client(tmp_path)

    first_session, _ = create_and_start(client)
    client.post("/api/calls/before", json=make_before("s1-discover"))
    finish(client, "s1-discover")
    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    assert client.post(f"/api/interfaces/{interface_id}/breakpoint", json={}).get_json()["success"]
    client.post("/api/debug/stop")

    second_session = client.post("/api/sessions", json={}).get_json()["sessionId"]
    assert second_session != first_session
    client.post("/api/debug/start", json={})
    assert client.post("/api/calls/before", json=make_before("s2-same")).get_json()["action"] == "continue"
    finish(client, "s2-same")

    assert client.get("/api/breakpoints").get_json()["items"] == []

    client.post(f"/api/sessions/{first_session}/select")
    first_breakpoints = client.get("/api/breakpoints").get_json()["items"]
    assert len(first_breakpoints) == 1


def test_command_and_params_snapshot_breakpoints(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("seed", params={"mode": "A"}))
    finish(client, "seed")

    call_id = client.get("/api/calls").get_json()["items"][0]["call_id"]
    assert client.post(f"/api/calls/{call_id}/breakpoint", json={"matchMode": "params_snapshot"}).get_json()["success"]

    paused = client.post("/api/calls/before", json=make_before("hit", params={"mode": "A"})).get_json()
    assert paused["action"] == "pause"
    assert client.get("/api/debug/state").get_json()["state"] == "DEBUGGING_PAUSED"
    assert client.post("/api/calls/hit/continue").get_json()["released"] is True

    missed = client.post("/api/calls/before", json=make_before("miss", params={"mode": "B"})).get_json()
    assert missed["action"] == "continue"


def test_clear_and_delete_session_respect_session_boundaries(tmp_path):
    client = make_client(tmp_path)

    first_session, _ = create_and_start(client)
    client.post("/api/calls/before", json=make_before("clear-me"))
    finish(client, "clear-me")
    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    client.post(f"/api/interfaces/{interface_id}/breakpoint", json={})
    client.post("/api/debug/stop")

    cleared = client.post("/api/sessions/current/clear")
    assert cleared.status_code == 200
    assert client.get("/api/calls").get_json()["items"] == []
    assert client.get("/api/interfaces").get_json()["items"] == []
    assert len(client.get("/api/breakpoints").get_json()["items"]) == 1

    second_session = client.post("/api/sessions", json={}).get_json()["sessionId"]
    deleted = client.delete(f"/api/sessions/{first_session}")
    assert deleted.status_code == 200
    sessions = client.get("/api/sessions").get_json()["items"]
    assert [item["id"] for item in sessions] == [second_session]
    assert client.get("/api/breakpoints", query_string={"sessionId": first_session}).get_json()["items"] == []


def test_grouped_endpoints_return_object_groups(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("sa", object_name="SA", cmd="start"))
    finish(client, "sa")
    client.post("/api/calls/before", json=make_before("sg", object_name="SG", cmd="start", params={"freq": 1}))
    finish(client, "sg")

    call_groups = client.get("/api/calls/grouped").get_json()["groups"]
    interface_groups = client.get("/api/interfaces/grouped").get_json()["groups"]
    assert {group["objectName"] for group in call_groups} == {"SA", "SG"}
    assert {group["objectName"] for group in interface_groups} == {"SA", "SG"}


def test_legacy_core_module_delegates_to_session_debug_service(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})

    with app.app_context():
        from app.services import core, debug_service

        assert core.STATE is debug_service.STATE
        assert core.create_session({})["success"] is True
        assert core.start_session("record", {})["success"] is False

        started = core.start_session("debug", {})
        assert started["debugging"] is True
        assert isinstance(core.stop_activity(), int)
        assert core.STATE["debugging"] is False
