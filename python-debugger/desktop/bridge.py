import json

import requests
from PySide6.QtCore import QObject, Signal, Slot


class Bridge(QObject):
    stateChanged = Signal(str)
    callsChanged = Signal(str)
    interfacesChanged = Signal(str)
    breakpointsChanged = Signal(str)
    sessionsChanged = Signal(str)
    resultChanged = Signal(str)

    def __init__(self):
        super().__init__()
        self.backend = "http://127.0.0.1:5050"

    def _request(self, method, url, **kwargs):
        try:
            response = requests.request(method, url, timeout=8, **kwargs)
            text = response.text
            try:
                return response.json()
            except ValueError:
                return {"success": response.ok, "text": text}
        except Exception as exc:
            return {"success": False, "error": str(exc)}

    def _emit_result(self, value):
        self.resultChanged.emit(json.dumps(value, ensure_ascii=False, indent=2))

    @Slot()
    def startRecord(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/session/start-record", json={}))
        self.refreshAll()

    @Slot()
    def stopRecord(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/session/stop-record"))
        self.refreshAll()

    @Slot()
    def startDebug(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/session/start-debug", json={}))
        self.refreshAll()

    @Slot()
    def stopDebug(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/session/stop-debug"))
        self.refreshAll()

    @Slot()
    def continueAll(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/calls/continue-all"))
        self.refreshAll()

    @Slot()
    def clearCalls(self):
        self._emit_result(self._request("DELETE", f"{self.backend}/api/calls"))
        self.refreshAll()

    @Slot()
    def clearSessions(self):
        self._emit_result(self._request("DELETE", f"{self.backend}/api/session"))
        self.refreshAll()

    @Slot()
    def createSession(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/session/create", json={"serviceName": "instrument-service-demo", "operator": "developer"}))
        self.refreshAll()

    @Slot(str)
    def selectSession(self, sessionId):
        self._emit_result(self._request("POST", f"{self.backend}/api/session/{sessionId}/select"))
        self.refreshAll()

    @Slot()
    def refreshAll(self):
        self.loadState()
        self.loadSessions()
        self.loadCalls()
        self.loadInterfaces()
        self.loadBreakpoints()

    @Slot()
    def loadState(self):
        self.stateChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/debug/state"), ensure_ascii=False))

    @Slot()
    def loadSessions(self):
        self.sessionsChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/session"), ensure_ascii=False))

    @Slot()
    def loadCalls(self):
        self.callsChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/calls"), ensure_ascii=False))

    @Slot()
    def loadInterfaces(self):
        self.interfacesChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/interfaces"), ensure_ascii=False))

    @Slot()
    def loadBreakpoints(self):
        self.breakpointsChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/breakpoints"), ensure_ascii=False))

    @Slot(str)
    def continueCall(self, callId):
        self._emit_result(self._request("POST", f"{self.backend}/api/calls/{callId}/continue"))
        self.refreshAll()

    @Slot(str)
    def createBreakpointFromInterface(self, interfaceId):
        self._emit_result(self._request("POST", f"{self.backend}/api/interfaces/{interfaceId}/breakpoint", json={"enabled": True, "hitMode": "always"}))
        self.refreshAll()

    @Slot(str)
    def createBreakpointFromCall(self, callId):
        self._emit_result(self._request("POST", f"{self.backend}/api/calls/{callId}/breakpoint", json={"enabled": True, "selectedArgs": ["cmdName"], "hitMode": "always"}))
        self.refreshAll()

    @Slot(str, bool)
    def setBreakpointEnabled(self, breakpointId, enabled):
        action = "enable" if enabled else "disable"
        self._emit_result(self._request("POST", f"{self.backend}/api/breakpoints/{breakpointId}/{action}"))
        self.refreshAll()

    @Slot(str)
    def deleteBreakpoint(self, breakpointId):
        self._emit_result(self._request("DELETE", f"{self.backend}/api/breakpoints/{breakpointId}"))
        self.refreshAll()

    @Slot(str)
    def javaPing(self, baseUrl):
        self._emit_result(self._request("GET", f"{baseUrl.rstrip('/')}/api/demo/ping"))

    @Slot(str)
    def javaInitialize(self, baseUrl):
        self._emit_result(self._request("GET", f"{baseUrl.rstrip('/')}/api/demo/initialize"))
        self.refreshAll()

    @Slot(str, str, str, int)
    def javaControl(self, baseUrl, instType, cmdName, slotId):
        url = f"{baseUrl.rstrip('/')}/api/demo/control"
        self._emit_result(self._request("GET", url, params={"instType": instType, "cmdName": cmdName, "slotId": slotId}))
        self.refreshAll()

    @Slot(str)
    def javaControlCreate(self, baseUrl):
        self.javaControl(baseUrl, "VNA", "create", 1)

    @Slot(str)
    def javaControlStart(self, baseUrl):
        self.javaControl(baseUrl, "VNA", "start", 1)

    @Slot(str)
    def javaControlStop(self, baseUrl):
        self.javaControl(baseUrl, "VNA", "stop", 1)

    @Slot(str)
    def javaError(self, baseUrl):
        self._emit_result(self._request("GET", f"{baseUrl.rstrip('/')}/api/demo/error"))
        self.refreshAll()
