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
