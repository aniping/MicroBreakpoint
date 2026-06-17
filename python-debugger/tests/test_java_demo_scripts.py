from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_call_all_demo_apis_script_covers_java_demo_rest_endpoints():
    script = (ROOT / "java-demo" / "scripts" / "call-all-demo-apis.ps1").read_text(encoding="utf-8")

    assert "curl.exe" in script
    assert "/api/demo/ping" in script
    assert "/api/demo/initialize" in script
    assert "/api/demo/control" in script
    assert '"instType":"VNA"' in script
    assert '"instType":"SA"' in script
    assert '"instType":"DMM"' in script
    assert '"instType":"PSU"' in script
    assert '"instType":"OSC"' in script
    assert script.count('-Path "/api/demo/initialize"') >= 5
    assert script.count('-Path "/api/demo/control"') >= 14
    assert script.count('"cmdName":"start"') >= 3
    assert script.count('"cmdName":"measure"') >= 3
    assert "micro-breakpoint-large-text-" in script
    assert 'cmdName = "largeText"' in script
    assert "ConvertTo-Json -Compress -Depth 6" in script


def test_debugger_ports_are_configured_for_18601():
    python_config = (ROOT / "python-debugger" / "desktop" / "config.py").read_text(encoding="utf-8")
    run_backend = (ROOT / "python-debugger" / "run_backend.py").read_text(encoding="utf-8")
    flask_app = (ROOT / "python-debugger" / "app" / "__init__.py").read_text(encoding="utf-8")
    run_desktop = (ROOT / "python-debugger" / "run_desktop.py").read_text(encoding="utf-8")
    bridge = (ROOT / "python-debugger" / "desktop" / "bridge.py").read_text(encoding="utf-8")
    runtime = (ROOT / "python-debugger" / "desktop" / "backend_runtime.py").read_text(encoding="utf-8")
    app_settings = (ROOT / "python-debugger" / "desktop" / "app_settings.py").read_text(encoding="utf-8")
    settings_page = (ROOT / "python-debugger" / "desktop" / "qml" / "SettingsTab.qml").read_text(encoding="utf-8")
    java_yml = (ROOT / "java-demo" / "src" / "main" / "resources" / "application.yml").read_text(encoding="utf-8")
    java_settings = (ROOT / "java-demo" / "src" / "main" / "java" / "com" / "example" / "instrumentdemo" / "debuger" / "DebuggerSettings.java").read_text(encoding="utf-8")
    java_config = (ROOT / "java-demo" / "src" / "main" / "java" / "com" / "example" / "instrumentdemo" / "debuger" / "DebuggerSettingsConfig.java").read_text(encoding="utf-8")
    java_debugger_yml = (ROOT / "java-debugger" / "src" / "main" / "resources" / "application.yml").read_text(encoding="utf-8")

    assert "BACKEND_PORT = 18601" in python_config
    assert "BACKEND_PORT" in run_backend
    assert 'default="internal"' in run_desktop
    assert '"internal"' in run_desktop
    assert '"jar"' in run_desktop
    assert '"external"' in run_desktop
    assert '"none"' not in run_desktop
    assert "MICRO_BREAKPOINT_DATABASE" in run_backend
    assert "MICRO_BREAKPOINT_DEMO_BASE_URL" not in run_backend
    assert "MICRO_BREAKPOINT_DEMO_REQUEST_TIMEOUT_MS" not in run_backend
    assert "MICRO_BREAKPOINT_DEMO_BASE_URL" not in flask_app
    assert "MICRO_BREAKPOINT_DEMO_REQUEST_TIMEOUT_MS" not in flask_app
    assert "SERVER_PORT" in run_backend
    assert "BACKEND_URL" in bridge
    assert "getAppSettings" in bridge
    assert "saveAppSettings" in bridge
    assert "BACKEND_PORT" in runtime
    assert "micro-breakpoint.settings-file" in runtime
    assert "MICRO_BREAKPOINT_DEMO_BASE_URL" not in runtime
    assert "MICRO_BREAKPOINT_DEMO_REQUEST_TIMEOUT_MS" not in runtime
    assert "create_app" in runtime
    assert "make_server" in runtime
    assert "run_backend.py" not in runtime
    assert "_app_base_dir" in runtime
    assert "sys.executable" in runtime
    assert "spring-boot:run" not in runtime
    assert "mvn" not in runtime.lower()
    assert "settings.json" in app_settings
    assert "debugTarget" in app_settings
    assert "page.backendUrl" in settings_page
    assert "服务 IP / Host" in settings_page
    assert "断点启用接口" in settings_page
    assert "settingsSaveRequested" in settings_page
    assert "http://127.0.0.1:18601" in java_yml
    assert "enabled: false" in java_yml
    assert "http://127.0.0.1:18601" in java_settings
    assert "public static volatile boolean enabled = false" in java_settings
    assert "${debugger.enabled:false}" in java_config
    assert "${debugger.server-url:http://127.0.0.1:18601}" in java_config
    assert "settings-file: ../python-debugger/data/settings.json" in java_debugger_yml
    assert "demo-base-url" not in java_debugger_yml
    assert "demo-request-timeout-ms" not in java_debugger_yml


def test_object_cmd_bash_scripts_cover_discovery_and_breakpoints():
    discovery = (ROOT / "scripts" / "test_object_cmd_discovery.sh").read_text(encoding="utf-8")
    breakpoint = (ROOT / "scripts" / "test_object_cmd_breakpoint.sh").read_text(encoding="utf-8")

    assert "DEBUGGER_URL" in discovery
    assert "DEMO_URL" in discovery
    assert "instType=VNA&cmdName=create&slotId=1" in discovery
    assert "instType=VNA&cmdName=create&slotId=2" in discovery
    assert "Python 查询结果应显示 objectName" in discovery
    assert "/api/interfaces/" in breakpoint
    assert "/api/calls/continue-all" in breakpoint
    assert "matchMode\":\"params_snapshot" in breakpoint
