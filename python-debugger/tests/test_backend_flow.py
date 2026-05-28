from app import create_app
from app.db.database import get_db


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
        "rawArgs": {"objectName": object_name, "cmdName": cmd, "slotId": slot_id, "params": params},
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


def session_by_id(client, session_id):
    return {item["id"]: item for item in client.get("/api/sessions").get_json()["items"]}[session_id]


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
    assert "params" not in calls[0]
    assert "result" not in calls[0]
    assert calls[0]["params_summary"] == "mode=A"

    interfaces = client.get("/api/interfaces").get_json()["items"]
    by_cmd = {item["cmd_name"]: item for item in interfaces}
    assert set(by_cmd) == {"start", "stop"}
    assert by_cmd["start"]["session_id"] == session_id
    assert by_cmd["start"]["call_count"] == 2
    assert by_cmd["start"]["params_sample_count"] == 2
    assert by_cmd["stop"]["call_count"] == 1


def test_call_list_is_lightweight_and_payload_is_chunked(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    create_and_start(client)
    big_params = {"points": 1601, "data": ["x" * 1024] * 80}
    big_result = {"trace": ["y" * 1024] * 90}
    client.post("/api/calls/before", json=make_before("large-call", object_name="VNA", cmd="acquire", params=big_params))
    client.post("/api/calls/after", json={"callId": "large-call", "success": True, "costMs": 283, "result": big_result})

    item = client.get("/api/calls").get_json()["items"][0]
    assert "params" not in item
    assert "result" not in item
    assert "params_json" not in item
    assert "result_json" not in item
    assert item["params_size"] > 64 * 1024
    assert item["result_size"] > 64 * 1024
    assert item["params_truncated"] == 1
    assert item["result_truncated"] == 1

    detail = client.get("/api/calls/large-call").get_json()
    assert detail["params_preview"].startswith("{")
    assert len(detail["params_preview"].encode("utf-8")) <= 8192 * 2
    assert "params" not in detail
    assert "result" not in detail

    chunk = client.get("/api/calls/large-call/payload", query_string={"type": "result", "offset": 0, "limit": 4096}).get_json()
    assert chunk["size"] == item["result_size"]
    assert chunk["hasMore"] is True
    assert len(chunk["content"].encode("utf-8")) <= 4096 * 2

    exported = client.get("/api/calls/large-call/payload/export", query_string={"type": "result"})
    assert exported.status_code == 200
    assert b"trace" in exported.data[:128]

    with app.app_context():
        db = get_db()
        payload_rows = db.execute("SELECT storage_type, content_text, content_path FROM call_payloads WHERE call_id='large-call'").fetchall()
        assert {row["storage_type"] for row in payload_rows} == {"file"}
        assert all(row["content_text"] is None for row in payload_rows)
        record = db.execute("SELECT params_json, result_json, raw_args_json FROM call_record WHERE call_id='large-call'").fetchone()
        assert record["params_json"] is None
        assert record["result_json"] is None
        assert "data" not in record["raw_args_json"]


def test_call_list_defaults_to_first_50_records(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    for index in range(60):
        call_id = f"page-{index}"
        client.post("/api/calls/before", json=make_before(call_id, params={"index": index}))
        finish(client, call_id)

    assert len(client.get("/api/calls").get_json()["items"]) == 50
    assert len(client.get("/api/calls", query_string={"pageSize": 100}).get_json()["items"]) == 60


def test_interface_identity_ignores_slot_and_service_name(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    first = make_before("slot-1", object_name="VNA", cmd="create", slot_id=1, params={"mode": "A"})
    second = make_before("slot-2", object_name="VNA", cmd="create", slot_id=2, params={"mode": "B"})
    third = make_before("slot-3", object_name="VNA", cmd="create", slot_id=3, params={"mode": "C"})
    third["serviceName"] = "another-service"
    client.post("/api/calls/before", json=first)
    finish(client, "slot-1")
    client.post("/api/calls/before", json=second)
    finish(client, "slot-2")
    client.post("/api/calls/before", json=third)
    finish(client, "slot-3")

    interfaces = client.get("/api/interfaces").get_json()["items"]
    assert len(interfaces) == 1
    assert interfaces[0]["object_name"] == "VNA"
    assert interfaces[0]["cmd_name"] == "create"
    assert interfaces[0]["slot_id"] is None
    assert interfaces[0]["slot_key"] is None
    assert interfaces[0]["call_count"] == 3
    assert interfaces[0]["params_sample_count"] == 3

    calls = client.get("/api/calls").get_json()["items"]
    assert {item["slot_id"] for item in calls} == {1, 2, 3}
    assert {item["interface_id"] for item in calls} == {interfaces[0]["id"]}
    assert all("raw_args" not in item for item in calls)

    detail = client.get(f"/api/interfaces/{interfaces[0]['id']}").get_json()
    assert {item["slot_id"] for item in detail["samples"]} == {1, 2, 3}
    assert all(item["object_name"] == "VNA" and item["cmd_name"] == "create" for item in detail["samples"])
    assert all("params" not in item and "params_json" not in item for item in detail["samples"])


def test_upsert_interface_uses_existing_interface_id_for_samples(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()
    session_id, _ = create_and_start(client)

    with app.app_context():
        db = get_db()
        db.execute(
            """INSERT INTO discovered_interface
               (id, session_id, object_name, cmd_name, slot_id, slot_key, service_name, method_name,
                call_count, success_count, exception_count, first_seen_at, last_seen_at, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?)""",
            (
                "legacy-interface-id",
                session_id,
                "VNA",
                "create",
                9,
                "9",
                "legacy-service",
                "legacyMethod",
                "2026-01-01T00:00:00",
                "2026-01-01T00:00:00",
                "2026-01-01T00:00:00",
                "2026-01-01T00:00:00",
            ),
        )
        db.commit()

    client.post("/api/calls/before", json=make_before("legacy-sample", object_name="VNA", cmd="create", slot_id=2, params={"mode": "A"}))

    with app.app_context():
        db = get_db()
        interfaces = db.execute(
            "SELECT id, call_count FROM discovered_interface WHERE session_id=? AND object_name=? AND cmd_name=?",
            (session_id, "VNA", "create"),
        ).fetchall()
        call = db.execute("SELECT interface_id FROM call_record WHERE call_id=?", ("legacy-sample",)).fetchone()
        sample = db.execute("SELECT interface_id, slot_id FROM interface_param_sample WHERE call_id=?", ("legacy-sample",)).fetchone()

    assert len(interfaces) == 1
    assert interfaces[0]["id"] == "legacy-interface-id"
    assert interfaces[0]["call_count"] == 1
    assert call["interface_id"] == "legacy-interface-id"
    assert sample["interface_id"] == "legacy-interface-id"
    assert sample["slot_id"] == 2


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
    assert interfaces[0]["slot_key"] is None
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

    missed_slot = client.post("/api/calls/before", json=make_before("miss-slot", slot_id=2, params={"mode": "A"})).get_json()
    assert missed_slot["action"] == "continue"

    paused = client.post("/api/calls/before", json=make_before("hit", slot_id=1, params={"mode": "A"})).get_json()
    assert paused["action"] == "pause"
    assert client.get("/api/debug/state").get_json()["state"] == "DEBUGGING_PAUSED"
    assert client.post("/api/calls/hit/continue").get_json()["released"] is True

    missed = client.post("/api/calls/before", json=make_before("miss", params={"mode": "B"})).get_json()
    assert missed["action"] == "continue"


def test_breakpoint_dedup_uses_business_identity_and_disables_command_breakpoint(tmp_path):
    client = make_client(tmp_path)
    create_and_start(client)

    command = client.post(
        "/api/breakpoints",
        json={"objectName": "VNA", "cmdName": "create", "matchMode": "command_only"},
    ).get_json()
    assert command["success"] is True
    duplicate_command = client.post(
        "/api/breakpoints",
        json={"objectName": "VNA", "cmdName": "create", "matchMode": "command_only", "methodName": "otherMethod"},
    ).get_json()
    assert duplicate_command == {
        "success": False,
        "code": "DUPLICATE_COMMAND_BREAKPOINT",
        "message": "该命令断点已存在，请勿重复创建。",
    }

    condition = client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "create",
            "slotId": "1",
            "matchMode": "params_snapshot",
            "paramsFingerprint": "fp-a",
        },
    ).get_json()
    assert condition["success"] is True
    assert condition["disabledCommandBreakpointCount"] == 1
    assert condition["message"] == "条件断点已创建，已自动停用对应命令断点。"

    breakpoints = client.get("/api/breakpoints").get_json()["items"]
    by_mode = {item["match_mode"]: item for item in breakpoints}
    assert by_mode["command_only"]["enabled"] == 0
    assert by_mode["command_only"]["breakpointTypeLabel"] == "命令断点"
    assert by_mode["params_snapshot"]["slot_key"] == "1"
    assert by_mode["params_snapshot"]["breakpointTypeLabel"] == "条件断点"

    duplicate_snapshot = client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "create",
            "slotKey": "1",
            "matchMode": "params_snapshot",
            "paramsFingerprint": "fp-a",
        },
    ).get_json()
    assert duplicate_snapshot == {
        "success": False,
        "code": "DUPLICATE_CONDITION_BREAKPOINT",
        "message": "相同条件断点已存在，请勿重复创建。",
    }

    assert client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "create",
            "slotId": 2,
            "matchMode": "params_snapshot",
            "paramsFingerprint": "fp-a",
        },
    ).get_json()["success"] is True
    assert client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "create",
            "slotId": 1,
            "matchMode": "params_snapshot",
            "paramsFingerprint": "fp-b",
        },
    ).get_json()["success"] is True


def test_params_condition_dedup_normalizes_condition_order(tmp_path):
    client = make_client(tmp_path)
    create_and_start(client)

    first = client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "start",
            "slotId": 1,
            "matchMode": "params_condition",
            "conditions": [
                {"path": "params.mode", "operator": "eq", "value": "A"},
                {"path": "slotId", "operator": "eq", "value": 1},
            ],
        },
    ).get_json()
    assert first["success"] is True

    duplicate = client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "start",
            "slotKey": "1",
            "matchMode": "params_condition",
            "conditions": [
                {"value": 1, "operator": "eq", "path": "slotId"},
                {"value": "A", "path": "params.mode"},
            ],
        },
    ).get_json()
    assert duplicate == {
        "success": False,
        "code": "DUPLICATE_CONDITION_BREAKPOINT",
        "message": "相同条件断点已存在，请勿重复创建。",
    }


def test_command_breakpoint_ignores_slot_id(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    create_and_start(client)
    created = client.post(
        "/api/breakpoints",
        json={"objectName": "VNA", "cmdName": "create", "slotId": 1, "matchMode": "command_only"},
    ).get_json()
    assert created["success"] is True
    breakpoint = client.get("/api/breakpoints").get_json()["items"][0]
    assert breakpoint["name"] == "VNA create"
    assert breakpoint["slot_id"] is None
    assert breakpoint["condition"] == {"objectName": "VNA", "cmdName": "create"}

    with app.app_context():
        db = get_db()
        db.execute("UPDATE breakpoint SET slot_id=1, slot_key='1' WHERE id=?", (created["breakpointId"],))
        db.commit()

    hit_slot_2 = client.post("/api/calls/before", json=make_before("command-hit-slot-2", object_name="VNA", cmd="create", slot_id=2)).get_json()
    assert hit_slot_2["action"] == "pause"
    client.post("/api/calls/command-hit-slot-2/continue")


def test_slot_id_can_match_as_params_condition(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    created = client.post(
        "/api/breakpoints",
        json={
            "objectName": "VNA",
            "cmdName": "create",
            "slotId": 1,
            "matchMode": "params_condition",
            "conditions": [{"path": "slotId", "operator": "eq", "value": 1}],
        },
    ).get_json()
    assert created["success"] is True

    missed_slot = client.post("/api/calls/before", json=make_before("condition-miss-slot-2", object_name="VNA", cmd="create", slot_id=2)).get_json()
    assert missed_slot["action"] == "continue"

    hit_slot = client.post("/api/calls/before", json=make_before("condition-hit-slot-1", object_name="VNA", cmd="create", slot_id=1)).get_json()
    assert hit_slot["action"] == "pause"
    client.post("/api/calls/condition-hit-slot-1/continue")


def test_interface_breakpoint_matches_all_slots_for_object_and_command(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("seed-slot-1", object_name="VNA", cmd="create", slot_id=1))
    finish(client, "seed-slot-1")
    interface = client.get("/api/interfaces").get_json()["items"][0]
    created = client.post(f"/api/interfaces/{interface['id']}/breakpoint", json={}).get_json()
    assert created["success"] is True
    breakpoint = client.get("/api/breakpoints").get_json()["items"][0]
    assert breakpoint["name"] == "VNA create"
    assert breakpoint["slot_id"] is None
    assert breakpoint["condition"] == {"objectName": "VNA", "cmdName": "create"}

    hit_slot_1 = client.post("/api/calls/before", json=make_before("hit-slot-1", object_name="VNA", cmd="create", slot_id=1)).get_json()
    assert hit_slot_1["action"] == "pause"
    client.post("/api/calls/hit-slot-1/continue")

    hit_slot_2 = client.post("/api/calls/before", json=make_before("hit-slot-2", object_name="VNA", cmd="create", slot_id=2)).get_json()
    assert hit_slot_2["action"] == "pause"
    client.post("/api/calls/hit-slot-2/continue")

    miss_cmd = client.post("/api/calls/before", json=make_before("miss-cmd", object_name="VNA", cmd="start", slot_id=1)).get_json()
    assert miss_cmd["action"] == "continue"


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
    assert cleared.get_json()["deletedCount"]["breakpoints"] == 1
    assert client.get("/api/calls").get_json()["items"] == []
    assert client.get("/api/interfaces").get_json()["items"] == []
    assert client.get("/api/breakpoints").get_json()["items"] == []

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


def test_create_session_assigns_incrementing_display_names(tmp_path):
    client = make_client(tmp_path)

    first = client.post("/api/sessions", json={}).get_json()["sessionId"]
    second = client.post("/api/sessions", json={}).get_json()["sessionId"]
    custom = client.post("/api/sessions", json={"displayName": "手工命名"}).get_json()["sessionId"]
    third = client.post("/api/sessions", json={}).get_json()["sessionId"]

    assert session_by_id(client, first)["display_name"] == "未命名 1"
    assert session_by_id(client, second)["display_name"] == "未命名 2"
    assert session_by_id(client, custom)["display_name"] == "手工命名"
    assert session_by_id(client, third)["display_name"] == "未命名 3"


def test_startup_restores_last_open_session_and_ignores_deleted_session(tmp_path):
    db_path = tmp_path / "debugger.sqlite3"
    app = create_app({"TESTING": True, "DATABASE": str(db_path)})
    client = app.test_client()

    session_id = client.post("/api/sessions", json={}).get_json()["sessionId"]
    assert client.get("/api/debug/state").get_json()["sessionId"] == session_id

    restarted = create_app({"TESTING": True, "DATABASE": str(db_path)})
    restarted_client = restarted.test_client()
    assert restarted_client.get("/api/debug/state").get_json()["sessionId"] == session_id

    restarted_client.delete(f"/api/sessions/{session_id}")
    clean_restart = create_app({"TESTING": True, "DATABASE": str(db_path)})
    clean_client = clean_restart.test_client()
    state = clean_client.get("/api/debug/state").get_json()
    assert state["hasSession"] is False
    assert state["sessionId"] is None


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
    with client.application.app_context():
        from app.db.database import get_db

        db = get_db()
        db.execute("UPDATE call_record SET cost_ms=99 WHERE call_id='batch-running'")
        db.commit()

    registered = client.post("/api/calls/batch-success/interface").get_json()
    assert registered["success"] is True
    assert registered["updatedCallCount"] == 4
    assert registered["totalInterfaceCallCount"] == 4

    calls = client.get("/api/calls").get_json()["items"]
    same_slot = [item for item in calls if item["slot_key"] == "1"]
    other_slot = [item for item in calls if item["slot_key"] == "2"][0]
    assert {item["interface_id"] for item in same_slot} == {registered["interfaceId"]}
    assert all(item["interface_registered"] == 1 for item in same_slot)
    assert other_slot["interface_registered"] == 1
    assert other_slot["interface_id"] == registered["interfaceId"]

    interface = client.get("/api/interfaces").get_json()["items"][0]
    assert interface["id"] == registered["interfaceId"]
    assert interface["call_count"] == 4
    assert interface["success_count"] == 1
    assert interface["exception_count"] == 1
    assert interface["avg_cost_ms"] == 20
    assert interface["max_cost_ms"] == 30
    assert interface["min_cost_ms"] == 10
    assert interface["params_sample_count"] == 4
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


def test_archive_id_stays_stable_across_renamed_exports_and_duplicate_import(tmp_path):
    source_client = make_client(tmp_path / "source")

    source_session, _ = create_and_start(source_client)
    assert session_by_id(source_client, source_session)["archive_id"] is None

    first_archive = source_client.post(
        f"/api/sessions/{source_session}/export",
        json={"archiveName": "first archive.mbrec", "remark": "one"},
    ).get_json()["archive"]
    archive_id = first_archive["archiveId"]
    assert archive_id
    assert first_archive["session"]["archive_id"] == archive_id
    exported_source = session_by_id(source_client, source_session)
    assert exported_source["archive_id"] == archive_id
    assert exported_source["archive_name"] == "first archive.mbrec"
    assert exported_source["archive_remark"] == "one"
    assert exported_source["display_name"] == "first archive"
    assert exported_source["import_file_name"] is None
    assert exported_source["imported_at"] is None

    renamed_archive = source_client.post(
        f"/api/sessions/{source_session}/export",
        json={"archiveName": "renamed archive.MBREC", "remark": "two"},
    ).get_json()["archive"]
    assert renamed_archive["archiveId"] == archive_id
    assert renamed_archive["archiveName"] == "renamed archive.MBREC"
    assert renamed_archive["session"]["archive_id"] == archive_id
    renamed_source = session_by_id(source_client, source_session)
    assert renamed_source["archive_id"] == archive_id
    assert renamed_source["archive_name"] == "renamed archive.MBREC"
    assert renamed_source["archive_remark"] == "two"
    assert renamed_source["display_name"] == "renamed archive"
    assert renamed_source["import_file_name"] is None
    assert renamed_source["imported_at"] is None

    target_client = make_client(tmp_path / "target")
    imported = target_client.post(
        "/api/sessions/import",
        json={"archive": first_archive, "importFileName": "VNA初始化流程.mbrec"},
    )
    assert imported.status_code == 200
    imported_session = imported.get_json()["importedSessionId"]
    imported_item = session_by_id(target_client, imported_session)
    assert imported_item["archive_id"] == archive_id
    assert imported_item["import_file_name"] == "VNA初始化流程.mbrec"
    assert imported_item["display_name"] == "VNA初始化流程"

    exported_import = target_client.post(
        f"/api/sessions/{imported_session}/export",
        json={"archiveName": "export imported again"},
    ).get_json()["archive"]
    assert exported_import["archiveId"] == archive_id

    duplicate_session = target_client.post("/api/sessions", json={}).get_json()["sessionId"]
    target_client.post("/api/debug/start", json={})
    target_client.post(
        "/api/breakpoints",
        json={"objectName": "SA", "cmdName": "dup-pause", "slotId": 1, "matchMode": "command_only"},
    )
    assert target_client.post("/api/calls/before", json=make_before("paused-before-duplicate", cmd="dup-pause")).get_json()["action"] == "pause"

    duplicate = target_client.post(
        "/api/sessions/import",
        json={"archive": renamed_archive, "importFileName": "Renamed.MBREC"},
    )
    assert duplicate.status_code == 409
    duplicate_payload = duplicate.get_json()
    assert duplicate_payload["success"] is False
    assert duplicate_payload["message"] == "archive already imported"
    assert duplicate_payload["existingSessionId"] == imported_session
    assert duplicate_payload["openExisting"] is True
    assert duplicate_payload["archiveId"] == archive_id
    assert duplicate_payload["archiveName"] == "renamed archive.MBREC"
    assert duplicate_payload["importFileName"] == "Renamed.MBREC"
    assert "releasedCount" not in duplicate_payload

    state = target_client.get("/api/debug/state").get_json()
    assert state["debugging"] is True
    assert state["sessionId"] == duplicate_session
    assert state["pausedCount"] == 1
    duplicate_calls = target_client.get("/api/calls").get_json()["items"]
    assert duplicate_calls[0]["call_id"] == "paused-before-duplicate"
    assert duplicate_calls[0]["status"] == "paused"


def test_session_archive_import_stops_debug_loads_import_and_rejects_duplicate(tmp_path):
    source_client = make_client(tmp_path / "source")

    source_session, _ = create_and_start(source_client)
    source_client.post("/api/calls/before", json=make_before("archived-call", cmd="start", params={"mode": "A"}))
    finish(source_client, "archived-call")
    exported = source_client.post(
        f"/api/sessions/{source_session}/export",
        json={"archiveName": "first archive", "remark": "review note"},
    ).get_json()
    assert exported["success"] is True
    archive = exported["archive"]
    assert archive["extension"] == ".mbrec"
    assert archive["archiveName"] == "first archive"
    assert archive["remark"] == "review note"

    client = make_client(tmp_path / "target")
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
    assert imported_session != paused_session

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
    source_client = make_client(tmp_path / "source")

    source_session, _ = create_and_start(source_client)
    source_client.post(
        "/api/breakpoints",
        json={"objectName": "SA", "cmdName": "archive-paused", "slotId": 1, "matchMode": "command_only"},
    )
    assert source_client.post("/api/calls/before", json=make_before("archived-paused-call", cmd="archive-paused")).get_json()["action"] == "pause"
    archive = source_client.post(
        f"/api/sessions/{source_session}/export",
        json={"archiveName": "paused archive", "remark": "paused note"},
    ).get_json()["archive"]

    client = make_client(tmp_path / "target")
    imported = client.post("/api/sessions/import", json={"archive": archive}).get_json()
    assert imported["success"] is True
    imported_calls = client.get("/api/calls").get_json()["items"]
    assert len(imported_calls) == 1
    assert imported_calls[0]["status"] == "imported_paused"
    detail = client.get(f"/api/calls/{imported_calls[0]['call_id']}").get_json()
    assert detail["continued_at"] is None
    assert client.get("/api/debug/state").get_json()["pausedCount"] == 0
    continued = client.post(f"/api/calls/{imported_calls[0]['call_id']}/continue").get_json()
    assert continued["success"] is False
    assert client.get("/api/calls").get_json()["items"][0]["status"] == "imported_paused"


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
