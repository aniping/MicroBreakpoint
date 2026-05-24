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


def test_debugger_ports_are_configured_for_18601():
    python_config = (ROOT / "python-debugger" / "desktop" / "config.py").read_text(encoding="utf-8")
    run_backend = (ROOT / "python-debugger" / "run_backend.py").read_text(encoding="utf-8")
    bridge = (ROOT / "python-debugger" / "desktop" / "bridge.py").read_text(encoding="utf-8")
    runtime = (ROOT / "python-debugger" / "desktop" / "backend_runtime.py").read_text(encoding="utf-8")
    settings_page = (ROOT / "python-debugger" / "desktop" / "qml" / "SettingsTab.qml").read_text(encoding="utf-8")
    java_yml = (ROOT / "java-demo" / "src" / "main" / "resources" / "application.yml").read_text(encoding="utf-8")
    java_settings = (ROOT / "java-demo" / "src" / "main" / "java" / "com" / "example" / "instrumentdemo" / "debuger" / "DebuggerSettings.java").read_text(encoding="utf-8")
    java_config = (ROOT / "java-demo" / "src" / "main" / "java" / "com" / "example" / "instrumentdemo" / "debuger" / "DebuggerSettingsConfig.java").read_text(encoding="utf-8")

    assert "BACKEND_PORT = 18601" in python_config
    assert "BACKEND_PORT" in run_backend
    assert "BACKEND_URL" in bridge
    assert "BACKEND_PORT" in runtime
    assert "page.backendUrl" in settings_page
    assert "http://127.0.0.1:18601" in java_yml
    assert "http://127.0.0.1:18601" in java_settings
    assert "${debugger.server-url:http://127.0.0.1:18601}" in java_config
