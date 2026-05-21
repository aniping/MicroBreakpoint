import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from desktop.backend_runtime import DesktopBackendRuntime
from desktop.bridge import Bridge


def main():
    backend = DesktopBackendRuntime()
    backend.start()
    app = QApplication(sys.argv)
    app.aboutToQuit.connect(backend.stop)
    engine = QQmlApplicationEngine()
    bridge = Bridge()
    engine.rootContext().setContextProperty("bridge", bridge)
    qml = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        backend.stop()
        sys.exit(1)
    sys.exit(app.exec())
