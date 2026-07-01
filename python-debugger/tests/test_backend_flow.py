from io import BytesIO
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from threading import Thread
import zipfile

import pytest

from app import create_app
from app.db.database import get_db
import desktop.app_settings as app_settings


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


@pytest.fixture(autouse=True)
def demo_switch_server(monkeypatch):
    server, state = start_demo_switch_server()
    monkeypatch.setitem(app_settings.DEFAULT_SETTINGS["debugTarget"], "host", "127.0.0.1")
    monkeypatch.setitem(app_settings.DEFAULT_SETTINGS["debugTarget"], "port", server.server_port)
    monkeypatch.setitem(app_settings.DEFAULT_SETTINGS["debugTarget"], "debuggerSwitchPath", "/api/demo/debugger/enabled")
    monkeypatch.setitem(app_settings.DEFAULT_SETTINGS["debugTarget"], "requestTimeoutMs", 200)
    try:
        yield state
    finally:
        server.shutdown()
        server.server_close()


def create_and_start(client):
    created = client.post("/api/sessions", json={}).get_json()
    started = client.post("/api/debug/start", json={}).get_json()
    return created["sessionId"], started


def start_demo_switch_server():
    state = {"enabled": False}

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/api/demo/debugger/enabled":
                self.send_response(404)
                self.end_headers()
                return
            body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).replace(b" ", b"")
            state["enabled"] = b'"enabled":true' in body
            payload = json.dumps({"success": True, "enabled": state["enabled"]}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json;charset=UTF-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format, *args):
            return

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, state


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


def test_debug_start_and_stop_toggle_demo_switch(tmp_path, demo_switch_server):
    client = make_client(tmp_path)

    assert demo_switch_server["enabled"] is False

    _, started = create_and_start(client)

    assert started["debugging"] is True
    assert demo_switch_server["enabled"] is True

    stopped = client.post("/api/debug/stop").get_json()

    assert stopped["success"] is True
    assert stopped["debugging"] is False
    assert demo_switch_server["enabled"] is False


def test_debug_start_fails_when_demo_switch_is_unavailable(tmp_path):
    settings_file = tmp_path / "settings.json"
    app_settings.save_settings({
        "debugTarget": {
            "host": "127.0.0.1",
            "port": 1,
            "debuggerSwitchPath": "/api/demo/debugger/enabled",
            "requestTimeoutMs": 50,
        },
    }, settings_file)
    app = create_app({
        "TESTING": True,
        "DATABASE": str(tmp_path / "debugger.sqlite3"),
        "SETTINGS_FILE": str(settings_file),
    })
    client = app.test_client()

    response = client.post("/api/debug/start", json={})
    payload = response.get_json()

    assert response.status_code == 400
    assert payload["success"] is False
    assert payload["debugging"] is False
    assert payload["mode"] == "idle"
    assert "Java Demo" in payload["message"]


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
    parsed_params_preview = json.loads(detail["params_preview"])
    parsed_result_preview = json.loads(detail["result_preview"])
    assert isinstance(parsed_params_preview, dict)
    assert isinstance(parsed_result_preview, dict)
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


def test_interface_sample_payload_loads_by_payload_id(tmp_path):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    create_and_start(client)
    big_params = {"data": ["sample-payload-id"] + ["x" * 1024] * 80}
    client.post("/api/calls/before", json=make_before("sample-large", object_name="VNA", cmd="sample", params=big_params))

    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    sample = client.get(f"/api/interfaces/{interface_id}/samples").get_json()["items"][0]
    payload_id = sample["paramsPayloadId"]
    assert payload_id

    with app.app_context():
        db = get_db()
        db.execute("UPDATE interface_param_sample SET call_id=NULL WHERE id=?", (sample["id"],))
        db.commit()

    sample_without_call = client.get(f"/api/interfaces/{interface_id}/samples").get_json()["items"][0]
    assert sample_without_call["call_id"] is None
    assert sample_without_call["paramsPayloadId"] == payload_id

    chunk = client.get(f"/api/payloads/{payload_id}", query_string={"offset": 0, "limit": 4096}).get_json()
    assert chunk["success"] is True
    assert chunk["payloadId"] == payload_id
    assert "sample-payload-id" in chunk["content"]


def test_interface_sample_contains_preview_fields(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("sample-preview", object_name="VNA", cmd="preview", params={"mode": "A"}))

    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    sample = client.get(f"/api/interfaces/{interface_id}/samples").get_json()["items"][0]
    for key in ("paramsPreview", "paramsSize", "paramsHash", "paramsPayloadId", "paramsTruncated"):
        assert key in sample
    assert sample["paramsPreview"].startswith("{")
    assert sample["paramsSize"] > 0
    assert sample["paramsPayloadId"]
    assert sample["paramsTruncated"] is False


def test_payload_chunk_by_id_and_export(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    big_params = {"voltage": 5.0, "data": ["payload-export-by-id"] + ["z" * 1024] * 80}
    client.post("/api/calls/before", json=make_before("payload-id-export", object_name="VNA", cmd="export", params=big_params))

    detail = client.get("/api/calls/payload-id-export").get_json()
    payload_id = detail["paramsPayloadId"]
    chunk = client.get(f"/api/payloads/{payload_id}", query_string={"offset": 0, "limit": 4096}).get_json()
    assert chunk["success"] is True
    assert chunk["size"] == detail["params_size"]
    assert "payload-export-by-id" in chunk["content"]

    fragment = client.post(
        "/api/agent/payloads/fragment",
        json={"payload_ref": payload_id, "field_path": "request.parameters.voltage"},
    ).get_json()
    assert fragment["ok"] is True
    assert fragment["status"] == "available"
    assert fragment["value"] == 5.0

    exported = client.get(f"/api/payloads/{payload_id}/export")
    assert exported.status_code == 200
    assert b"payload-export-by-id" in exported.data[:512]


def test_payload_search_by_id(tmp_path, monkeypatch):
    client = make_client(tmp_path)

    create_and_start(client)
    big_params = {"trace": ["a" * 1024] * 70 + ["payload-id-needle"] + ["b" * 1024] * 70}
    client.post("/api/calls/before", json=make_before("payload-id-search", object_name="VNA", cmd="search", params=big_params))

    detail = client.get("/api/calls/payload-id-search").get_json()
    import app.services.payload_store as payload_store

    def fail_full_read(_row):
        raise AssertionError("search must not read the full payload")

    monkeypatch.setattr(payload_store, "read_payload_text", fail_full_read)
    found = client.get(
        f"/api/payloads/{detail['paramsPayloadId']}/search",
        query_string={"q": "payload-id-needle"},
    ).get_json()
    assert found["success"] is True
    assert found["matches"]
    assert "payload-id-needle" in found["matches"][0]["preview"]


def test_call_detail_contains_technical_fields(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    before = make_before("technical-fields", object_name="VNA", cmd="tech", params={"mode": "A"})
    before["serviceName"] = "svc-tech"
    before["className"] = "com.example.TechService"
    before["methodName"] = "measureTech"
    before["displayName"] = "Tech Display"
    before["threadName"] = "tech-thread"
    before["parameterMeta"] = [{"name": "mode", "javaType": "java.lang.String"}]
    client.post("/api/calls/before", json=before)

    detail = client.get("/api/calls/technical-fields").get_json()
    assert detail["service_name"] == "svc-tech"
    assert detail["class_name"] == "com.example.TechService"
    assert detail["method_name"] == "measureTech"
    assert detail["display_name"] == "Tech Display"
    assert detail["thread_name"] == "tech-thread"
    assert detail["parameter_meta"] == [{"name": "mode", "javaType": "java.lang.String"}]


def test_list_api_does_not_return_legacy_large_fields(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("legacy-lightweight", object_name="VNA", cmd="light", params={"mode": "A"}))
    finish(client, "legacy-lightweight")

    forbidden = {
        "params", "result", "params_json", "result_json", "latest_params_json",
        "sample_args_json", "params_snapshot_json", "rawArgs", "raw_args",
    }
    call_item = client.get("/api/calls").get_json()["items"][0]
    interface_item = client.get("/api/interfaces").get_json()["items"][0]
    assert forbidden.isdisjoint(call_item)
    assert forbidden.isdisjoint(interface_item)


def test_large_text_payload_preview_is_valid_json(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    large_text = "micro-breakpoint-large-text-" * 4096
    client.post(
        "/api/calls/before",
        json=make_before(
            "large-text-call",
            object_name="VNA",
            cmd="largeText",
            params={"scenario": "large-text-payload", "text": large_text, "expectedChars": len(large_text)},
        ),
    )
    finish(client, "large-text-call")

    detail = client.get("/api/calls/large-text-call").get_json()
    preview = json.loads(detail["params_preview"])
    assert preview["scenario"] == "large-text-payload"
    assert preview["expectedChars"] == len(large_text)
    assert preview["text"].startswith("micro-breakpoint-large-text-")
    assert preview["text"].endswith("…")
    assert len(preview["text"]) < len(large_text)
    assert len(preview["text"]) <= 181


def test_large_top_level_string_result_preview_is_valid_json(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    large_text = "micro-breakpoint-top-level-string-" * 4096
    client.post("/api/calls/before", json=make_before("top-level-string-call", object_name="VNA", cmd="largeString"))
    client.post(
        "/api/calls/after",
        json={"callId": "top-level-string-call", "success": True, "costMs": 5, "result": large_text},
    )

    detail = client.get("/api/calls/top-level-string-call").get_json()
    preview = json.loads(detail["result_preview"])
    assert preview.startswith("micro-breakpoint-top-level-string-")
    assert preview.endswith("…")
    assert len(preview) < len(large_text)
    assert len(preview) <= 181


def test_large_object_key_payload_preview_is_valid_bounded_json(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    long_key = "micro-breakpoint-large-object-key-" * 256
    params = {f"{long_key}{index}": {"value": index} for index in range(30)}
    client.post(
        "/api/calls/before",
        json=make_before("large-object-key-call", object_name="VNA", cmd="largeObject", params=params),
    )
    finish(client, "large-object-key-call")

    detail = client.get("/api/calls/large-object-key-call").get_json()
    preview_text = detail["params_preview"]
    preview = json.loads(preview_text)
    assert isinstance(preview, dict)
    assert "__preview__" in preview
    assert preview["__preview__"]["keyCount"] == 30
    assert preview["__preview__"]["shownKeys"] == 6
    assert preview["__preview__"]["omittedKeys"] == 24
    assert all(len(key) < 180 for key in preview if key != "__preview__")
    assert len(preview_text.encode("utf-8")) <= 8192


def test_payload_search_streaming_file(tmp_path, monkeypatch):
    app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    client = app.test_client()

    create_and_start(client)
    big_result = {"trace": ["a" * 1024] * 70 + ["needle-cross-boundary"] + ["b" * 1024] * 70}
    client.post("/api/calls/before", json=make_before("search-large", object_name="VNA", cmd="acquire"))
    client.post("/api/calls/after", json={"callId": "search-large", "success": True, "costMs": 10, "result": big_result})

    import app.services.payload_store as payload_store

    def fail_full_read(_row):
        raise AssertionError("search must not read the full payload")

    monkeypatch.setattr(payload_store, "read_payload_text", fail_full_read)
    found = client.get(
        "/api/calls/search-large/payload/search",
        query_string={"type": "result", "q": "needle-cross-boundary"},
    ).get_json()
    assert found["matches"]
    assert found["matches"][0]["offset"] > 64 * 1024
    assert "needle-cross-boundary" in found["matches"][0]["preview"]
    missing = client.get(
        "/api/calls/search-large/payload/search",
        query_string={"type": "result", "q": "not-present"},
    ).get_json()
    assert missing["matches"] == []


def test_archive_does_not_inline_large_payload(tmp_path):
    source_app = create_app({"TESTING": True, "DATABASE": str(tmp_path / "source" / "debugger.sqlite3")})
    source_client = source_app.test_client()
    source_session, _ = create_and_start(source_client)
    big_result = {"trace": ["payload-marker-" + ("x" * 1024)] * 90}
    source_client.post("/api/calls/before", json=make_before("archive-large", object_name="VNA", cmd="acquire"))
    source_client.post("/api/calls/after", json={"callId": "archive-large", "success": True, "costMs": 10, "result": big_result})

    archive_response = source_client.post(
        f"/api/sessions/{source_session}/export-file",
        json={"archiveName": "large archive"},
    )
    assert archive_response.status_code == 200
    with zipfile.ZipFile(BytesIO(archive_response.data)) as archive_zip:
        names = archive_zip.namelist()
        assert "db.json" in names
        payload_names = [name for name in names if name.startswith("payloads/") and name.endswith("/result.json")]
        assert payload_names
        db_json = archive_zip.read("db.json").decode("utf-8")
        assert len(db_json.encode("utf-8")) < 50 * 1024
        db_payload = json.loads(db_json)
        result_payload = [item for item in db_payload["callPayloads"] if item["payload_type"] == "result"][0]
        assert "export_content_text" not in result_payload

    target_client = make_client(tmp_path / "target")
    imported = target_client.post(
        "/api/sessions/import-file",
        data={"file": (BytesIO(archive_response.data), "large archive.mbrec"), "lockInterfaces": "0"},
        content_type="multipart/form-data",
    )
    assert imported.status_code == 200
    imported_call = target_client.get("/api/calls").get_json()["items"][0]
    chunk = target_client.get(
        f"/api/calls/{imported_call['call_id']}/payload",
        query_string={"type": "result", "offset": 0, "limit": 4096},
    ).get_json()
    assert chunk["size"] > 64 * 1024
    assert "payload-marker" in chunk["content"]


def test_call_list_defaults_to_first_50_records(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    for index in range(60):
        call_id = f"page-{index}"
        client.post("/api/calls/before", json=make_before(call_id, params={"index": index}))
        finish(client, call_id)

    assert len(client.get("/api/calls").get_json()["items"]) == 50
    assert len(client.get("/api/calls", query_string={"pageSize": 100}).get_json()["items"]) == 60


def test_call_list_sql_pagination(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    for index in range(120):
        call_id = f"sql-page-{index}"
        client.post("/api/calls/before", json=make_before(call_id, params={"index": index}))
        finish(client, call_id)

    first = client.get("/api/calls").get_json()
    second = client.get("/api/calls", query_string={"page": 2, "pageSize": 50}).get_json()
    assert first["success"] is True
    assert first["page"] == 1
    assert first["pageSize"] == 50
    assert first["total"] == 120
    assert len(first["items"]) == 50
    assert second["page"] == 2
    assert second["pageSize"] == 50
    assert second["total"] == 120
    assert len(second["items"]) == 50
    assert first["items"][0]["call_index"] == 120
    assert second["items"][0]["call_index"] == 70
    forbidden = {"params", "result", "rawArgs", "raw_args", "params_json", "result_json"}
    assert forbidden.isdisjoint(first["items"][0])


def test_call_list_sql_filter_keyword_status_object(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("vna-acquire", object_name="VNA", cmd="acquire", params={"mode": "fast"}))
    finish(client, "vna-acquire")
    client.post("/api/calls/before", json=make_before("vna-error", object_name="VNA", cmd="stop", params={"mode": "slow"}))
    finish(client, "vna-error", success=False)
    client.post("/api/calls/before", json=make_before("sg-acquire", object_name="SG", cmd="acquire", params={"freq": 1}))
    finish(client, "sg-acquire")

    by_object = client.get("/api/calls", query_string={"objectName": "VNA"}).get_json()
    assert by_object["total"] == 2
    assert {item["object_name"] for item in by_object["items"]} == {"VNA"}

    by_status = client.get("/api/calls", query_string={"status": "exception"}).get_json()
    assert by_status["total"] == 1
    assert by_status["items"][0]["call_id"] == "vna-error"

    by_keyword = client.get("/api/calls", query_string={"keyword": "acquire"}).get_json()
    assert by_keyword["total"] == 2
    assert {item["call_id"] for item in by_keyword["items"]} == {"vna-acquire", "sg-acquire"}


def test_interface_list_sql_pagination(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    for index in range(120):
        call_id = f"iface-page-{index}"
        client.post("/api/calls/before", json=make_before(call_id, object_name="VNA", cmd=f"cmd-{index}", params={"index": index}))
        finish(client, call_id)

    first = client.get("/api/interfaces").get_json()
    second = client.get("/api/interfaces", query_string={"page": 2, "pageSize": 50}).get_json()
    assert first["success"] is True
    assert first["page"] == 1
    assert first["pageSize"] == 50
    assert first["total"] == 120
    assert len(first["items"]) == 50
    assert second["page"] == 2
    assert second["pageSize"] == 50
    assert second["total"] == 120
    assert len(second["items"]) == 50
    forbidden = {"latest_params_json", "sample_args_json", "params"}
    assert forbidden.isdisjoint(first["items"][0])


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


def test_agent_declare_breakpoint_rule_registers_without_observed_interface(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    declared = client.post(
        "/api/agent/breakpoints",
        json={
            "target": {"object": "VNA", "command": "initialize"},
            "match": {"type": "interface"},
        },
    ).get_json()
    assert declared["ok"] is True
    assert declared["status"] == "armed"
    assert declared["meta"]["observation_hint"]["state"] == "unobserved"
    assert declared["breakpoint_rule_id"]

    duplicate = client.post(
        "/api/agent/breakpoints",
        json={
            "target": {"object": "VNA", "command": "initialize"},
            "match": {"type": "interface"},
        },
    ).get_json()
    assert duplicate["breakpoint_rule_id"] == declared["breakpoint_rule_id"]

    rules = client.get("/api/agent/breakpoints").get_json()
    assert rules["ok"] is True
    assert rules["breakpoint_rules"][0]["breakpoint_rule_id"] == declared["breakpoint_rule_id"]

    rule = client.get(f"/api/agent/breakpoints/{declared['breakpoint_rule_id']}").get_json()
    assert rule["ok"] is True
    assert rule["status"] == "armed"

    disabled = client.post(f"/api/agent/breakpoints/{declared['breakpoint_rule_id']}/disable").get_json()
    assert disabled["ok"] is True
    assert disabled["status"] == "disabled"
    skipped = client.post(
        "/api/calls/before",
        json=make_before("agent-vna-init-disabled", object_name="VNA", cmd="initialize"),
    ).get_json()
    assert skipped["action"] == "continue"
    timeout = client.post(
        "/api/agent/interactions/wait-paused",
        json={
            "breakpoint_rule_id": declared["breakpoint_rule_id"],
            "target": {"object": "VNA", "command": "initialize"},
            "timeout_ms": 1,
        },
    ).get_json()
    assert timeout["ok"] is False
    assert timeout["status"] == "timeout"

    enabled = client.post(f"/api/agent/breakpoints/{declared['breakpoint_rule_id']}/enable").get_json()
    assert enabled["ok"] is True
    assert enabled["status"] == "armed"

    cancelled_watch = client.post(
        "/api/agent/interactions/paused/watch",
        json={"target": {"object": "VNA", "command": "initialize"}},
    ).get_json()
    assert cancelled_watch["ok"] is True
    cancelled = client.delete(f"/api/agent/interactions/paused/watch/{cancelled_watch['watch_id']}").get_json()
    assert cancelled["ok"] is True
    assert cancelled["status"] == "cancelled"

    watch = client.post(
        "/api/agent/interactions/paused/watch",
        json={
            "breakpoint_rule_id": declared["breakpoint_rule_id"],
            "target": {"object": "VNA", "command": "initialize"},
        },
    ).get_json()
    assert watch["ok"] is True
    assert watch["status"] == "watching"

    paused = client.post(
        "/api/calls/before",
        json=make_before("agent-vna-init", object_name="VNA", cmd="initialize", params={"scenario": "vna-initialize"}),
    ).get_json()
    assert paused["action"] == "pause"

    events = client.get("/api/agent/events", query_string={"watch_id": watch["watch_id"]}).get_json()
    assert events["ok"] is True
    assert events["events"][0]["event"] == "interaction_paused"
    assert events["events"][0]["interaction_id"] == "agent-vna-init"

    explanation = client.post(
        f"/api/agent/breakpoints/{declared['breakpoint_rule_id']}/explain",
        json={"interaction_id": "agent-vna-init"},
    ).get_json()
    assert explanation["ok"] is True
    assert explanation["matched"] is True
    assert explanation["facts"]["rule_enabled"] is True
    assert explanation["facts"]["target_matched"] is True

    waited = client.post(
        "/api/agent/interactions/wait-paused",
        json={
            "breakpoint_rule_id": declared["breakpoint_rule_id"],
            "target": {"object": "VNA", "command": "initialize"},
            "timeout_ms": 1,
        },
    ).get_json()
    assert waited["ok"] is True
    assert waited["status"] == "paused"
    assert waited["interaction_id"] == "agent-vna-init"

    analysis = client.post(
        "/api/agent/interactions/analyze",
        json={"target": {"object": "VNA", "command": "initialize"}},
    ).get_json()
    assert analysis["ok"] is True
    analyzed = {item["interaction_id"]: item for item in analysis["interactions"]}
    assert "agent-vna-init" in analyzed
    assert analyzed["agent-vna-init"]["request_payload_ref"]
    assert any(item["type"] == "interaction" and item["id"] == "agent-vna-init" for item in analysis["entities"])

    compared = client.post(
        "/api/agent/interactions/compare",
        json={"interaction_ids": ["agent-vna-init-disabled", "agent-vna-init"]},
    ).get_json()
    assert compared["ok"] is True
    assert compared["differences"]
    assert {item["id"] for item in compared["entities"]} == {"agent-vna-init-disabled", "agent-vna-init"}

    paused_interactions = client.post(
        "/api/agent/interactions/paused/search",
        json={
            "breakpoint_rule_id": declared["breakpoint_rule_id"],
            "target": {"object": "VNA", "command": "initialize"},
        },
    ).get_json()
    assert paused_interactions["ok"] is True
    assert len(paused_interactions["interactions"]) == 1
    assert paused_interactions["interactions"][0]["interaction_id"] == "agent-vna-init"

    continued = client.post("/api/agent/interactions/agent-vna-init/continue").get_json()
    assert continued["ok"] is True
    assert continued["status"] == "continued"
    assert client.get("/api/calls/agent-vna-init").get_json()["status"] == "continued"

    deleted = client.delete(f"/api/agent/breakpoints/{declared['breakpoint_rule_id']}").get_json()
    assert deleted["ok"] is True
    assert deleted["status"] == "cancelled"
    after_delete = client.post(
        "/api/calls/before",
        json=make_before("agent-vna-init-after-delete", object_name="VNA", cmd="initialize"),
    ).get_json()
    assert after_delete["action"] == "continue"


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
    assert breakpoint["condition"] is None
    assert breakpoint["condition_fields"] == {}

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
    assert breakpoint["condition"] is None
    assert breakpoint["condition_fields"] == {}

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


def test_clear_call_records_keeps_interfaces_and_breakpoints(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    client.post("/api/calls/before", json=make_before("record-only-clear"))
    finish(client, "record-only-clear")
    interface_id = client.get("/api/interfaces").get_json()["items"][0]["id"]
    client.post(f"/api/interfaces/{interface_id}/breakpoint", json={})
    client.post("/api/debug/stop")

    cleared = client.post("/api/calls/clear")
    assert cleared.status_code == 200
    assert cleared.get_json()["deletedCount"]["calls"] == 1
    assert client.get("/api/calls").get_json()["items"] == []
    assert len(client.get("/api/interfaces").get_json()["items"]) == 1
    assert len(client.get("/api/interfaces/" + interface_id + "/samples").get_json()["items"]) == 1
    assert len(client.get("/api/breakpoints").get_json()["items"]) == 1


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


def test_grouped_calls_uses_full_session(tmp_path):
    client = make_client(tmp_path)

    create_and_start(client)
    for index in range(75):
        client.post("/api/calls/before", json=make_before(f"full-sa-{index}", object_name="SA", cmd=f"sa-{index}"))
        finish(client, f"full-sa-{index}")
    for index in range(25):
        client.post("/api/calls/before", json=make_before(f"full-vna-{index}", object_name="VNA", cmd=f"vna-{index}"))
        finish(client, f"full-vna-{index}", success=index != 0)

    assert len(client.get("/api/calls").get_json()["items"]) == 50
    call_groups = {group["objectName"]: group for group in client.get("/api/calls/grouped").get_json()["groups"]}
    assert call_groups["SA"]["callCount"] == 75
    assert call_groups["VNA"]["callCount"] == 25
    assert call_groups["VNA"]["exceptionCount"] == 1
    interface_groups = {group["objectName"]: group for group in client.get("/api/interfaces/grouped").get_json()["groups"]}
    assert interface_groups["SA"]["interfaceCount"] == 75
    assert interface_groups["VNA"]["interfaceCount"] == 25
    assert interface_groups["VNA"]["exceptionCount"] == 1


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
