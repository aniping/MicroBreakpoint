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


def test_clear_sessions_deletes_history_and_resets_state(tmp_path):
    client = make_client(tmp_path)

    first_session, _ = create_and_start(client)
    client.post("/api/calls/before", json=make_before("history-first"))
    finish(client, "history-first")
    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    client.post(f"/api/interfaces/{interface_id}/breakpoint", json={})
    client.post("/api/debug/stop")

    second_session = client.post("/api/sessions", json={}).get_json()["sessionId"]
    assert second_session != first_session
    client.post("/api/debug/start", json={})
    client.post("/api/calls/before", json=make_before("history-second", object_name="VNA"))
    finish(client, "history-second")
    client.post("/api/debug/stop")

    cleared = client.delete("/api/sessions")
    assert cleared.status_code == 200
    payload = cleared.get_json()
    assert payload["sessionId"] is None
    assert payload["state"] == "NO_SESSION"
    assert payload["deletedCount"]["sessions"] == 2
    assert payload["deletedCount"]["calls"] == 2
    assert payload["deletedCount"]["breakpoints"] == 1

    assert client.get("/api/sessions").get_json()["items"] == []
    assert client.get("/api/calls").get_json()["items"] == []
    assert client.get("/api/interfaces").get_json()["items"] == []
    assert client.get("/api/breakpoints").get_json()["items"] == []


def test_clear_sessions_requires_stopped_debugging(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)

    blocked = client.delete("/api/sessions")
    assert blocked.status_code == 400
    assert blocked.get_json()["success"] is False
    assert len(client.get("/api/sessions").get_json()["items"]) == 1


def test_interface_lock_marks_unregistered_calls_and_allows_manual_registration(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post(
        "/api/breakpoints",
        json={"objectName": "SA", "cmdName": "start", "slotId": 1, "matchMode": "command_only"},
    )
    locked = client.post("/api/interfaces/lock", json={"locked": True}).get_json()
    assert locked["interfaceLocked"] is True

    paused = client.post("/api/calls/before", json=make_before("locked-hit", cmd="start")).get_json()
    assert paused["action"] == "pause"
    assert paused["interfaceId"] is None
    assert client.get("/api/interfaces").get_json()["items"] == []

    call = client.get("/api/calls").get_json()["items"][0]
    assert call["interface_registered"] == 0
    assert call["discovery_enabled"] == 0
    assert call["status"] == "paused"

    client.post("/api/calls/locked-hit/continue")
    finish(client, "locked-hit")
    registered = client.post("/api/calls/locked-hit/interface").get_json()
    assert registered["success"] is True
    assert registered["updatedCallCount"] == 1
    assert registered["totalInterfaceCallCount"] == 1

    call = client.get("/api/calls").get_json()["items"][0]
    assert call["interface_registered"] == 1
    assert call["interface_id"] == registered["interfaceId"]
    interfaces = client.get("/api/interfaces").get_json()["items"]
    assert len(interfaces) == 1
    assert interfaces[0]["call_count"] == 1


def test_manual_registration_batches_same_unregistered_interface_and_recalculates_stats(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/interfaces/lock", json={"locked": True})
    client.post("/api/calls/before", json=make_before("batch-success", cmd="measure", params={"mode": "A"}))
    finish(client, "batch-success", success=True, cost_ms=10)
    client.post("/api/calls/before", json=make_before("batch-error", cmd="measure", params={"mode": "B"}))
    finish(client, "batch-error", success=False, cost_ms=30)
    client.post("/api/calls/before", json=make_before("batch-running", cmd="measure", params={"mode": "C"}))
    client.post("/api/calls/before", json=make_before("other-slot", cmd="measure", slot_id=2, params={"mode": "D"}))

    registered = client.post("/api/calls/batch-success/interface").get_json()
    assert registered["success"] is True
    assert registered["updatedCallCount"] == 3
    assert registered["totalInterfaceCallCount"] == 3

    calls = client.get("/api/calls").get_json()["items"]
    same_slot = [item for item in calls if item["slot_key"] == "1"]
    other_slot = [item for item in calls if item["slot_key"] == "2"][0]
    assert {item["interface_id"] for item in same_slot} == {registered["interfaceId"]}
    assert all(item["interface_registered"] == 1 for item in same_slot)
    assert other_slot["interface_registered"] == 0
    assert other_slot["interface_id"] is None

    interface = client.get("/api/interfaces").get_json()["items"][0]
    assert interface["id"] == registered["interfaceId"]
    assert interface["call_count"] == 3
    assert interface["success_count"] == 1
    assert interface["exception_count"] == 1
    assert interface["avg_cost_ms"] == 20
    assert interface["max_cost_ms"] == 30
    assert interface["min_cost_ms"] == 10
    assert interface["params_sample_count"] == 3
    assert interface["first_seen_at"]
    assert interface["last_seen_at"]


def test_interface_lock_still_updates_existing_interfaces(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("known", cmd="start"))
    finish(client, "known")
    first_interface = client.get("/api/interfaces").get_json()["items"][0]["id"]

    client.post("/api/interfaces/lock", json={"locked": True})
    client.post("/api/calls/before", json=make_before("known-again", cmd="start", params={"mode": "B"}))
    finish(client, "known-again")

    interfaces = client.get("/api/interfaces").get_json()["items"]
    assert len(interfaces) == 1
    assert interfaces[0]["id"] == first_interface
    assert interfaces[0]["call_count"] == 2
    assert interfaces[0]["params_sample_count"] == 2
    assert all(item["interface_registered"] == 1 for item in client.get("/api/calls").get_json()["items"])


def test_session_archive_import_stops_debug_loads_import_and_rejects_duplicate(tmp_path):
    client = make_client(tmp_path)

    source_session, _ = create_and_start(client)
    client.post("/api/calls/before", json=make_before("archived-call", cmd="start", params={"mode": "A"}))
    finish(client, "archived-call")
    exported = client.post(
        f"/api/sessions/{source_session}/export",
        json={"archiveName": "first archive", "remark": "review note"},
    ).get_json()
    assert exported["success"] is True
    archive = exported["archive"]
    assert archive["extension"] == ".mbrec"
    assert archive["archiveName"] == "first archive"
    assert archive["remark"] == "review note"

    paused_session = client.post("/api/sessions", json={}).get_json()["sessionId"]
    client.post("/api/debug/start", json={})
    client.post(
        "/api/breakpoints",
        json={"objectName": "SA", "cmdName": "pause-me", "slotId": 1, "matchMode": "command_only"},
    )
    assert client.post("/api/calls/before", json=make_before("paused-before-import", cmd="pause-me")).get_json()["action"] == "pause"

    imported = client.post("/api/sessions/import", json={"archive": archive, "lockInterfaces": True})
    assert imported.status_code == 200
    imported_payload = imported.get_json()
    imported_session = imported_payload["importedSessionId"]
    assert imported_payload["debugging"] is False
    assert imported_payload["sessionId"] == imported_session
    assert imported_payload["interfaceLocked"] is True
    assert imported_session not in {source_session, paused_session}

    paused_calls = client.get("/api/calls", query_string={"sessionId": paused_session}).get_json()["items"]
    assert paused_calls[0]["status"] == "continued"
    imported_calls = client.get("/api/calls").get_json()["items"]
    assert len(imported_calls) == 1
    assert imported_calls[0]["session_id"] == imported_session
    assert imported_calls[0]["call_id"] != "archived-call"
    assert len(client.get("/api/interfaces").get_json()["items"]) == 1

    duplicate_session = client.post("/api/sessions", json={}).get_json()["sessionId"]
    client.post("/api/debug/start", json={})
    client.post(
        "/api/breakpoints",
        json={"objectName": "SA", "cmdName": "dup-pause", "slotId": 1, "matchMode": "command_only"},
    )
    assert client.post("/api/calls/before", json=make_before("paused-before-duplicate", cmd="dup-pause")).get_json()["action"] == "pause"

    duplicate = client.post("/api/sessions/import", json={"archive": archive})
    assert duplicate.status_code == 409
    duplicate_payload = duplicate.get_json()
    assert duplicate_payload["success"] is False
    assert duplicate_payload["archiveName"] == "first archive"
    assert duplicate_payload["existingSessionId"] == imported_session
    assert duplicate_payload["openExisting"] is True
    assert "releasedCount" not in duplicate_payload

    state = client.get("/api/debug/state").get_json()
    assert state["debugging"] is True
    assert state["sessionId"] == duplicate_session
    assert state["pausedCount"] == 1
    duplicate_calls = client.get("/api/calls").get_json()["items"]
    assert duplicate_calls[0]["call_id"] == "paused-before-duplicate"
    assert duplicate_calls[0]["status"] == "paused"


def test_session_archive_import_converts_historical_paused_calls(tmp_path):
    client = make_client(tmp_path)

    source_session, _ = create_and_start(client)
    client.post(
        "/api/breakpoints",
        json={"objectName": "SA", "cmdName": "archive-paused", "slotId": 1, "matchMode": "command_only"},
    )
    assert client.post("/api/calls/before", json=make_before("archived-paused-call", cmd="archive-paused")).get_json()["action"] == "pause"
    archive = client.post(
        f"/api/sessions/{source_session}/export",
        json={"archiveName": "paused archive", "remark": "paused note"},
    ).get_json()["archive"]

    imported = client.post("/api/sessions/import", json={"archive": archive}).get_json()
    assert imported["success"] is True
    imported_calls = client.get("/api/calls").get_json()["items"]
    assert len(imported_calls) == 1
    assert imported_calls[0]["status"] == "imported_paused"
    assert imported_calls[0]["continued_at"] is None
    assert client.get("/api/debug/state").get_json()["pausedCount"] == 0


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
