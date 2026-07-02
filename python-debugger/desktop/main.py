import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from desktop.backend_runtime import DesktopBackendRuntime
from desktop.bridge import Bridge


def main(backend_mode="internal", backend_jar=None, backend_dir=None, qt_argv=None):
    backend = DesktopBackendRuntime(
        backend_mode=backend_mode,
        backend_jar=backend_jar,
        backend_dir=backend_dir,
    )
    backend.start()
    app = QApplication(qt_argv or sys.argv)
    app.setFont(QFont("Microsoft YaHei UI", 10))
    app.aboutToQuit.connect(backend.stop)
    engine = QQmlApplicationEngine()
    bridge = Bridge(backend_url=backend.url)
    engine.rootContext().setContextProperty("bridge", bridge)
    engine.rootContext().setContextProperty("backendApiUrl", backend.url)
    qml = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        backend.stop()
        sys.exit(1)
    sys.exit(app.exec())
