import json
from pathlib import Path

import requests
from PySide6.QtCore import QObject, QSettings, Signal, Slot
from PySide6.QtWidgets import QApplication, QFileDialog

from desktop.config import BACKEND_URL


class Bridge(QObject):
    stateChanged = Signal(str)
    callsChanged = Signal(str)
    interfacesChanged = Signal(str)
    breakpointsChanged = Signal(str)
    sessionsChanged = Signal(str)
    resultChanged = Signal(str)
    themeChanged = Signal(str)
    importDuplicate = Signal(str)
    userNotice = Signal(str)

    def __init__(self):
        super().__init__()
        self.backend = BACKEND_URL
        self.settings = QSettings("MicroBreakpoint", "Desktop")

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
        self.resultChanged.emit(json.dumps(self._log_safe_value(value), ensure_ascii=False, indent=2))
        message = value.get("message") if isinstance(value, dict) else None
        if message and (
            value.get("code") in ("DUPLICATE_COMMAND_BREAKPOINT", "DUPLICATE_CONDITION_BREAKPOINT")
            or message.startswith("条件断点已创建")
            or message == "当前会话数据已清空。"
        ):
            self.userNotice.emit(message)

    def _log_safe_value(self, value):
        if isinstance(value, list):
            return [self._log_safe_value(item) for item in value[:20]]
        if not isinstance(value, dict):
            return value
        result = {}
        for key, item in value.items():
            if key in ("params", "result", "rawArgs", "args", "params_json", "result_json", "latest_params", "sample_args", "params_snapshot"):
                result[key] = self._payload_log_summary(item)
            else:
                result[key] = self._log_safe_value(item)
        return result

    def _payload_log_summary(self, value):
        try:
            text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        except Exception:
            text = str(value)
        return {
            "payloadSaved": True,
            "size": len(text.encode("utf-8")),
            "summary": text[:180] + ("..." if len(text) > 180 else ""),
        }

    def _emit_operation_result(self, value, refresh=True):
        self._emit_result(value)
        if refresh:
            self.refreshAll()

    @Slot(result=str)
    def getThemeMode(self):
        value = self.settings.value("theme/mode", "dark")
        return "light" if value == "light" else "dark"

    @Slot(str)
    def setThemeMode(self, mode):
        theme_mode = "light" if mode == "light" else "dark"
        self.settings.setValue("theme/mode", theme_mode)
        self.settings.sync()
        self.themeChanged.emit(theme_mode)

    @Slot()
    def startRecord(self):
        self._emit_result({"success": False, "message": "记录模式已移除，请使用开始调试"})

    @Slot()
    def stopRecord(self):
        self._emit_result({"success": False, "message": "记录模式已移除，请使用停止调试"})

    @Slot()
    def startDebug(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/debug/start", json={}))
        self.refreshAll()

    @Slot()
    def stopDebug(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/debug/stop"))
        self.refreshAll()

    @Slot()
    def resetDebug(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/debug/reset"))
        self.refreshAll()

    @Slot()
    def continueAll(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/calls/continue-all"))
        self.refreshAll()

    @Slot()
    def clearCalls(self):
        result = self._request("POST", f"{self.backend}/api/sessions/current/clear")
        if result.get("success"):
            result["message"] = "当前会话数据已清空。"
        self._emit_operation_result(result)

    @Slot()
    def clearSessions(self):
        self._emit_result(self._request("DELETE", f"{self.backend}/api/sessions"))
        self.refreshAll()

    @Slot(str)
    def deleteSession(self, sessionId):
        self._emit_result(self._request("DELETE", f"{self.backend}/api/sessions/{sessionId}"))
        self.refreshAll()

    @Slot()
    def createSession(self):
        self._emit_result(self._request("POST", f"{self.backend}/api/sessions", json={"serviceName": "instrument-service-demo", "operator": "developer"}))
        self.refreshAll()

    @Slot(str)
    def selectSession(self, sessionId):
        self._emit_result(self._request("POST", f"{self.backend}/api/sessions/{sessionId}/select"))
        self.refreshAll()

    @Slot(str)
    def openExistingSession(self, sessionId):
        self.selectSession(sessionId)

    @Slot(str, str, str)
    def exportSession(self, sessionId, archiveName, remark):
        result = self._request(
            "POST",
            f"{self.backend}/api/sessions/{sessionId}/export",
            json={"archiveName": archiveName, "remark": remark},
        )
        if not result.get("success"):
            self._emit_result(result)
            return
        archive = result.get("archive") or {}
        suggested = self._archive_filename(archive.get("archiveName") or archiveName or sessionId)
        path, _ = QFileDialog.getSaveFileName(None, "导出组件化断点调试工具会话", suggested, "组件化断点调试工具归档 (*.mbrec)")
        if not path:
            self._emit_result({"success": False, "message": "export cancelled"})
            return
        if not path.lower().endswith(".mbrec"):
            path += ".mbrec"
        Path(path).write_text(json.dumps(archive, ensure_ascii=False, indent=2), encoding="utf-8")
        self._emit_result({"success": True, "message": "exported", "path": path, "archiveId": archive.get("archiveId")})

    @Slot(bool)
    def importSession(self, lockInterfaces):
        path, _ = QFileDialog.getOpenFileName(None, "导入组件化断点调试工具会话", "", "组件化断点调试工具归档 (*.mbrec)")
        if not path:
            self._emit_result({"success": False, "message": "import cancelled"})
            return
        try:
            archive = json.loads(Path(path).read_text(encoding="utf-8"))
        except Exception as exc:
            self._emit_result({"success": False, "message": f"invalid archive: {exc}"})
            return
        result = self._request(
            "POST",
            f"{self.backend}/api/sessions/import",
            json={"archive": archive, "lockInterfaces": lockInterfaces, "importFileName": Path(path).name},
        )
        self._handle_import_result(result)
        self.refreshAll()

    def _handle_import_result(self, result):
        self._emit_result(result)
        if not result.get("success") and result.get("openExisting") and result.get("existingSessionId"):
            self.importDuplicate.emit(json.dumps(result, ensure_ascii=False))

    def _archive_filename(self, name):
        cleaned = "".join(char if char not in '<>:"/\\|?*' else "_" for char in str(name or "session")).strip()
        return f"{cleaned or 'session'}.mbrec"

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
        self.sessionsChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/sessions"), ensure_ascii=False))

    @Slot()
    def loadCalls(self):
        self.callsChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/calls", params={"pageSize": 50}), ensure_ascii=False))

    @Slot()
    def loadInterfaces(self):
        self.interfacesChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/interfaces", params={"pageSize": 50}), ensure_ascii=False))

    @Slot()
    def loadBreakpoints(self):
        self.breakpointsChanged.emit(json.dumps(self._request("GET", f"{self.backend}/api/breakpoints"), ensure_ascii=False))

    @Slot(str)
    def continueCall(self, callId):
        self._emit_result(self._request("POST", f"{self.backend}/api/calls/{callId}/continue"))
        self.refreshAll()

    @Slot(str)
    def createBreakpointFromInterface(self, interfaceId):
        self._emit_operation_result(self._request("POST", f"{self.backend}/api/interfaces/{interfaceId}/breakpoint", json={"enabled": True, "matchMode": "command_only", "hitMode": "always"}))

    @Slot(str)
    def createBreakpointFromCall(self, callId):
        self._emit_operation_result(self._request("POST", f"{self.backend}/api/calls/{callId}/breakpoint", json={"enabled": True, "matchMode": "params_snapshot", "hitMode": "always"}))

    @Slot(str)
    def addInterfaceFromCall(self, callId):
        self._emit_result(self._request("POST", f"{self.backend}/api/calls/{callId}/interface"))
        self.refreshAll()

    @Slot(str)
    def createMethodBreakpointFromCall(self, callId):
        self._emit_operation_result(self._request("POST", f"{self.backend}/api/calls/{callId}/breakpoint", json={"enabled": True, "matchMode": "command_only", "hitMode": "always"}))

    @Slot(str)
    def copyText(self, text):
        clipboard = QApplication.clipboard()
        if clipboard:
            clipboard.setText(text)
            self._emit_result({"success": True, "message": "已复制到剪贴板"})

    @Slot(str, str, int, int, result=str)
    def loadPayloadChunk(self, callId, payloadType, offset, limit):
        result = self._request(
            "GET",
            f"{self.backend}/api/calls/{callId}/payload",
            params={"type": payloadType, "offset": offset, "limit": limit},
        )
        return json.dumps(result, ensure_ascii=False)

    @Slot(str, result=str)
    def callDetail(self, callId):
        if not callId:
            return "{}"
        return json.dumps(self._request("GET", f"{self.backend}/api/calls/{callId}"), ensure_ascii=False)

    @Slot(str, result=str)
    def interfaceDetail(self, interfaceId):
        if not interfaceId:
            return "{}"
        return json.dumps(self._request("GET", f"{self.backend}/api/interfaces/{interfaceId}"), ensure_ascii=False)

    @Slot(str, int, int, result=str)
    def interfaceSamples(self, interfaceId, offset, limit):
        if not interfaceId:
            return '{"items":[]}'
        result = self._request(
            "GET",
            f"{self.backend}/api/interfaces/{interfaceId}/samples",
            params={"offset": offset, "limit": limit},
        )
        return json.dumps(result, ensure_ascii=False)

    @Slot(str, str, str, result=str)
    def searchPayload(self, callId, payloadType, query):
        result = self._request(
            "GET",
            f"{self.backend}/api/calls/{callId}/payload/search",
            params={"type": payloadType, "q": query},
        )
        return json.dumps(result, ensure_ascii=False)

    @Slot(str, str)
    def exportPayload(self, callId, payloadType):
        suggested = f"{payloadType}.json"
        path, _ = QFileDialog.getSaveFileName(None, "导出完整 payload", suggested, "JSON (*.json);;Text (*.txt);;All Files (*)")
        if not path:
            self._emit_result({"success": False, "message": "export cancelled"})
            return
        response = requests.get(
            f"{self.backend}/api/calls/{callId}/payload/export",
            params={"type": payloadType},
            timeout=30,
        )
        if not response.ok:
            self._emit_result({"success": False, "message": "payload export failed", "status": response.status_code})
            return
        Path(path).write_bytes(response.content)
        self._emit_result({"success": True, "message": "payload exported", "path": path})

    @Slot(str, str)
    def setInterfaceAlias(self, interfaceId, alias):
        self._emit_result(self._request("PATCH", f"{self.backend}/api/interfaces/{interfaceId}/alias", json={"alias": alias}))
        self.refreshAll()

    @Slot(bool)
    def setInterfaceLocked(self, locked):
        self._emit_result(self._request("POST", f"{self.backend}/api/interfaces/lock", json={"locked": bool(locked)}))
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
