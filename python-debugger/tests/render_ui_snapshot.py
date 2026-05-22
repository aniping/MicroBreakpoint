import sys
from tempfile import TemporaryDirectory
from pathlib import Path

import requests
from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QFont, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from desktop.backend_runtime import DesktopBackendRuntime
from desktop.bridge import Bridge


def seed_backend(base):
    requests.post(base + "/api/sessions", json={}, timeout=3)
    requests.post(base + "/api/debug/start", json={}, timeout=3)
    for index in range(1, 11):
        method = "instrumentControl" if index % 2 == 0 else "instrumentInitialize"
        call_id = f"shot-{index}"
        args = {"instType": "VNA", "cmdName": "create" if index % 4 == 0 else "start", "slotId": 1, "params": {"source": "screenshot"}}
        requests.post(
            base + "/api/calls/before",
            json={
                "callId": call_id,
                "objectName": args["instType"],
                "cmdName": args["cmdName"],
                "slotId": args["slotId"],
                "params": args["params"],
                "serviceName": "instrument-service-demo",
                "className": "com.example.instrumentdemo.service.InstrumentServiceImpl",
                "methodName": method,
                "displayName": "仪表控制" if method == "instrumentControl" else "仪表初始化",
                "description": "通过槽位号转换 hid 号，操作对应仪器仪表实例",
                "threadName": f"http-nio-8080-exec-{index % 4 + 1}",
                "timestamp": 1,
                "rawArgs": args,
                "parameterMeta": [{"name": "cmdName", "displayName": "仪表操作", "description": "仪表操作", "javaType": "java.lang.String"}],
            },
            timeout=3,
        )
        requests.post(
            base + "/api/calls/after",
            json={
                "callId": call_id,
                "success": index != 5,
                "costMs": 15 + index,
                "result": {"code": 0, "message": "ok", "data": args},
                "exceptionType": None if index != 5 else "RuntimeException",
                "exceptionMessage": None if index != 5 else "simulated error",
            },
            timeout=3,
        )

    interfaces = requests.get(base + "/api/interfaces", timeout=3).json()["items"]
    for item in interfaces[:2]:
        requests.post(base + f"/api/interfaces/{item['id']}/breakpoint", json={}, timeout=3)
    requests.post(
        base + "/api/calls/before",
        json={
            "callId": "shot-paused",
            "objectName": "VNA",
            "cmdName": "create",
            "slotId": 1,
            "params": {"source": "screenshot"},
            "serviceName": "instrument-service-demo",
            "className": "com.example.instrumentdemo.service.InstrumentServiceImpl",
            "methodName": "instrumentControl",
            "displayName": "仪表控制",
            "description": "通过槽位号转换 hid 号，操作对应仪器仪表实例",
            "threadName": "http-nio-8080-exec-1",
            "timestamp": 1,
            "rawArgs": {"instType": "VNA", "cmdName": "create", "slotId": 1, "params": {"source": "screenshot"}},
            "parameterMeta": [{"name": "cmdName", "displayName": "仪表操作", "description": "仪表操作", "javaType": "java.lang.String"}],
        },
        timeout=3,
    )


def main():
    temp_dir = TemporaryDirectory()
    runtime = DesktopBackendRuntime(port=5052, app_config={"TESTING": True, "DATABASE": str(Path(temp_dir.name) / "debugger.sqlite3")})
    runtime.start()
    print("backend ready", flush=True)
    seed_backend(runtime.url)
    print("backend seeded", flush=True)

    app = QGuiApplication(sys.argv)
    app.setFont(QFont("Microsoft YaHei UI", 10))
    engine = QQmlApplicationEngine()
    bridge = Bridge()
    bridge.backend = runtime.url
    engine.rootContext().setContextProperty("bridge", bridge)
    engine.load(QUrl.fromLocalFile(str((Path(__file__).resolve().parents[1] / "desktop" / "qml" / "Main.qml").resolve())))
    if not engine.rootObjects():
        runtime.stop()
        raise SystemExit("QML failed to load")
    print("qml loaded", flush=True)

    root = engine.rootObjects()[0]
    root.setWidth(1448)
    root.setHeight(1070)
    root.setProperty("currentPage", 0)

    def capture():
        bridge.refreshAll()

        def grab():
            out = Path(__file__).resolve().parents[2] / "ui_current.png"
            screen = app.primaryScreen()
            screen.grabWindow(root.winId()).save(str(out))
            print(out, flush=True)
            runtime.stop()
            temp_dir.cleanup()
            app.quit()

        QTimer.singleShot(100, grab)

    QTimer.singleShot(500, capture)
    QTimer.singleShot(10000, app.quit)
    app.exec()
    runtime.stop()
    temp_dir.cleanup()


if __name__ == "__main__":
    main()
