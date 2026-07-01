package com.example.microbreakpoint.service;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import jakarta.annotation.PostConstruct;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.util.Jsons;
import com.example.microbreakpoint.util.TextUtil;

@Service
public class DebugService {

    private static final String UNCATEGORIZED_OBJECT = "未分类";
    private static final String UNKNOWN_COMMAND = "未知命令";
    private static final String NULL_SLOT_KEY = "__NULL__";
    private static final String INTERFACE_LOCK_SETTING = "interface_locked";
    private static final String CURRENT_SESSION_ID_SETTING = "current_session_id";
    private static final String CURRENT_SESSION_OPEN_SETTING = "current_session_open";
    private static final int DEFAULT_PAGE_SIZE = 50;
    private static final int MAX_PAGE_SIZE = 100;

    private final JdbcTemplate jdbc;
    private final PayloadService payloadService;
    private final WaitManager waitManager;

    private boolean debugging = false;
    private String mode = "idle";
    private String sessionId;

    public DebugService(DatabaseService databaseService, PayloadService payloadService, WaitManager waitManager) {
        this.jdbc = databaseService.jdbc();
        this.payloadService = payloadService;
        this.waitManager = waitManager;
    }

    @PostConstruct
    public synchronized void init() {
        waitManager.continueAll();
        restoreSessionState();
    }

    public synchronized void restoreSessionState() {
        String open = settingValue(CURRENT_SESSION_OPEN_SETTING);
        if (!"1".equals(open)) {
            debugging = false;
            mode = "idle";
            sessionId = null;
            return;
        }
        String savedSessionId = settingValue(CURRENT_SESSION_ID_SETTING);
        if (savedSessionId != null && exists("SELECT id FROM debug_session WHERE id=?", savedSessionId)) {
            debugging = false;
            mode = "idle";
            sessionId = savedSessionId;
            jdbc.update("UPDATE debug_session SET mode='idle', status='idle', recording=0, debugging=0 WHERE id=?",
                    savedSessionId);
        } else {
            debugging = false;
            mode = "idle";
            sessionId = null;
        }
    }

    public synchronized Map<String, Object> createSession(Map<String, Object> payload) {
        stopDebug();
        String newSessionId = "session-" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        String now = TextUtil.nowIso();
        String displayName = str(firstNonNull(payload.get("displayName"), payload.get("display_name"))).trim();
        if (displayName.isBlank()) {
            displayName = nextUntitledSessionName();
        }
        sessionId = newSessionId;
        debugging = false;
        mode = "idle";
        jdbc.update("""
                INSERT INTO debug_session
                (id, mode, status, service_name, operator, start_time, recording, debugging, remark, display_name, created_at, updated_at)
                VALUES (?, 'idle', 'idle', ?, ?, ?, 0, 0, ?, ?, ?, ?)
                """,
                newSessionId,
                strOr(payload.get("serviceName"), "instrument-service-demo"),
                strOr(payload.get("operator"), "developer"),
                now,
                strOr(payload.get("remark"), ""),
                displayName,
                now,
                now);
        saveCurrentSessionState(newSessionId);
        return stateResponse(mapOf("success", true, "sessionId", newSessionId));
    }

    public synchronized Map<String, Object> selectSession(String targetSessionId) {
        stopDebug();
        if (!exists("SELECT id FROM debug_session WHERE id=?", targetSessionId)) {
            return mapOf("success", false, "message", "session not found");
        }
        sessionId = targetSessionId;
        debugging = false;
        mode = "idle";
        saveCurrentSessionState(targetSessionId);
        return stateResponse(mapOf("success", true, "sessionId", targetSessionId));
    }

    public synchronized Map<String, Object> startDebug(Map<String, Object> payload) {
        if (sessionId == null) {
            createSession(payload == null ? Map.of() : payload);
        }
        String now = TextUtil.nowIso();
        debugging = true;
        mode = "debug";
        jdbc.update("""
                UPDATE debug_session
                SET mode='debug', status='debugging', recording=0, debugging=1, end_time=NULL, updated_at=?
                WHERE id=?
                """, now, sessionId);
        return stateResponse(mapOf("success", true));
    }

    public synchronized int stopDebug() {
        int released = waitManager.continueAll();
        if (sessionId != null) {
            String now = TextUtil.nowIso();
            jdbc.update("""
                    UPDATE call_record
                    SET status='continued', continued_at=?, updated_at=?
                    WHERE session_id=? AND status='paused'
                    """, now, now, sessionId);
            jdbc.update("""
                    UPDATE debug_session
                    SET mode='idle', status='idle', end_time=?, recording=0, debugging=0, updated_at=?
                    WHERE id=?
                    """, now, now, sessionId);
        }
        debugging = false;
        mode = "idle";
        return released;
    }

    public synchronized Map<String, Object> resetDebug() {
        int released = waitManager.continueAll();
        if (sessionId != null) {
            String now = TextUtil.nowIso();
            jdbc.update("""
                    UPDATE call_record
                    SET status='continued', continued_at=?, updated_at=?
                    WHERE session_id=? AND status='paused'
                    """, now, now, sessionId);
        }
        return stateResponse(mapOf("success", true, "releasedCount", released));
    }

    public synchronized Map<String, Object> clearCurrentSession() {
        if (debugging) {
            return mapOf("success", false, "message", "请先停止调试");
        }
        if (sessionId == null) {
            return mapOf("success", false, "message", "请先新建或选择会话");
        }
        String sid = sessionId;
        int released = waitManager.continueAll();
        Map<String, Object> counts = mapOf(
                "calls", count("SELECT COUNT(*) FROM call_record WHERE session_id=?", sid),
                "payloads", count("SELECT COUNT(*) FROM call_payloads WHERE session_id=?", sid),
                "interfaces", count("SELECT COUNT(*) FROM discovered_interface WHERE session_id=?", sid),
                "samples", count("""
                        SELECT COUNT(*) FROM interface_param_sample
                        WHERE interface_id IN (SELECT id FROM discovered_interface WHERE session_id=?)
                        """, sid),
                "breakpoints", count("SELECT COUNT(*) FROM breakpoint WHERE session_id=?", sid));
        jdbc.update("""
                DELETE FROM interface_param_sample
                WHERE interface_id IN (SELECT id FROM discovered_interface WHERE session_id=?)
                """, sid);
        jdbc.update("DELETE FROM breakpoint WHERE session_id=?", sid);
        jdbc.update("DELETE FROM call_payloads WHERE session_id=?", sid);
        jdbc.update("DELETE FROM call_record WHERE session_id=?", sid);
        jdbc.update("DELETE FROM discovered_interface WHERE session_id=?", sid);
        return stateResponse(mapOf("success", true, "deletedCount", counts, "releasedCount", released));
    }

    public synchronized Map<String, Object> clearCallRecords() {
        if (debugging) {
            return mapOf("success", false, "message", "请先停止调试");
        }
        if (sessionId == null) {
            return mapOf("success", false, "message", "请先新建或选择会话");
        }
        String sid = sessionId;
        Map<String, Object> counts = mapOf(
                "calls", count("SELECT COUNT(*) FROM call_record WHERE session_id=?", sid));
        jdbc.update("DELETE FROM call_record WHERE session_id=?", sid);
        return stateResponse(mapOf("success", true, "deletedCount", counts));
    }

    public synchronized Map<String, Object> deleteSession(String targetSessionId) {
        if (debugging) {
            return mapOf("success", false, "message", "请先停止调试");
        }
        if (!exists("SELECT id FROM debug_session WHERE id=?", targetSessionId)) {
            return mapOf("success", false, "message", "session not found");
        }
        Map<String, Object> counts = mapOf(
                "calls", count("SELECT COUNT(*) FROM call_record WHERE session_id=?", targetSessionId),
                "payloads", count("SELECT COUNT(*) FROM call_payloads WHERE session_id=?", targetSessionId),
                "interfaces", count("SELECT COUNT(*) FROM discovered_interface WHERE session_id=?", targetSessionId),
                "breakpoints", count("SELECT COUNT(*) FROM breakpoint WHERE session_id=?", targetSessionId));
        jdbc.update("""
                DELETE FROM interface_param_sample
                WHERE interface_id IN (SELECT id FROM discovered_interface WHERE session_id=?)
                """, targetSessionId);
        jdbc.update("DELETE FROM breakpoint WHERE session_id=?", targetSessionId);
        jdbc.update("DELETE FROM call_payloads WHERE session_id=?", targetSessionId);
        jdbc.update("DELETE FROM call_record WHERE session_id=?", targetSessionId);
        jdbc.update("DELETE FROM discovered_interface WHERE session_id=?", targetSessionId);
        jdbc.update("DELETE FROM debug_session WHERE id=?", targetSessionId);
        if (targetSessionId.equals(sessionId)) {
            debugging = false;
            mode = "idle";
            sessionId = null;
            saveCurrentSessionState(null);
        }
        return stateResponse(mapOf("success", true, "deletedSessionId", targetSessionId, "deletedCount", counts));
    }

    public synchronized Map<String, Object> clearSessions() {
        if (debugging) {
            return mapOf("success", false, "message", "请先停止调试");
        }
        Map<String, Object> counts = mapOf(
                "sessions", count("SELECT COUNT(*) FROM debug_session"),
                "calls", count("SELECT COUNT(*) FROM call_record"),
                "payloads", count("SELECT COUNT(*) FROM call_payloads"),
                "interfaces", count("SELECT COUNT(*) FROM discovered_interface"),
                "breakpoints", count("SELECT COUNT(*) FROM breakpoint"),
                "samples", count("SELECT COUNT(*) FROM interface_param_sample"));
        jdbc.update("DELETE FROM interface_param_sample");
        jdbc.update("DELETE FROM breakpoint");
        jdbc.update("DELETE FROM call_payloads");
        jdbc.update("DELETE FROM call_record");
        jdbc.update("DELETE FROM discovered_interface");
        jdbc.update("DELETE FROM debug_session");
        debugging = false;
        mode = "idle";
        sessionId = null;
        saveCurrentSessionState(null);
        return stateResponse(mapOf("success", true, "deletedCount", counts));
    }

    public synchronized Map<String, Object> stateResponse() {
        return stateResponse(Map.of());
    }

    public synchronized Map<String, Object> stateResponse(Map<String, Object> extra) {
        int callCount = 0;
        int interfaceCount = 0;
        int pausedCount = 0;
        int runningCount = 0;
        int exceptionCount = 0;
        Object lastReport = null;
        if (sessionId != null) {
            callCount = count("SELECT COUNT(*) FROM call_record WHERE session_id=?", sessionId);
            interfaceCount = count("SELECT COUNT(*) FROM discovered_interface WHERE session_id=?", sessionId);
            pausedCount = count("SELECT COUNT(*) FROM call_record WHERE session_id=? AND status='paused'", sessionId);
            runningCount = count(
                    "SELECT COUNT(*) FROM call_record WHERE session_id=? AND status IN ('running','continued')",
                    sessionId);
            exceptionCount = count("SELECT COUNT(*) FROM call_record WHERE session_id=? AND status='exception'",
                    sessionId);
            lastReport = scalar("SELECT MAX(updated_at) FROM call_record WHERE session_id=?", sessionId);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("success", true);
        data.put("state", stateName(pausedCount));
        data.put("debugging", debugging);
        data.put("recording", debugging);
        data.put("mode", mode);
        data.put("hasSession", sessionId != null);
        data.put("sessionId", sessionId);
        data.put("currentSessionId", sessionId);
        data.put("callCount", callCount);
        data.put("interfaceCount", interfaceCount);
        data.put("discoveredInterfaceCount", interfaceCount);
        data.put("breakpointCount", breakpointCount(sessionId));
        data.put("pausedCount", pausedCount);
        data.put("runningCount", runningCount);
        data.put("exceptionCount", exceptionCount);
        data.put("lastReportTime", lastReport);
        data.put("interfaceLocked", interfaceLocked());
        data.putAll(extra);
        return data;
    }

    public synchronized Map<String, Object> beforeCall(Map<String, Object> payload) {
        if (!debugging || sessionId == null) {
            return mapOf("success", true, "callIndex", 0, "action", "continue");
        }
        String now = TextUtil.nowIso();
        Map<String, Object> callData = callBusinessData(payload);
        String callId = str(payload.get("callId"));
        Map<String, Object> paramsPayload = payloadService.savePayload(sessionId, callId, "params",
                callData.get("params"), now);
        callData.put("params_summary", paramsPayload.get("summary"));
        callData.put("params_preview", paramsPayload.get("preview"));
        callData.put("params_size", paramsPayload.get("size"));
        callData.put("params_hash", callData.get("params_fingerprint"));
        callData.put("params_truncated", bool(paramsPayload.get("truncated")) ? 1 : 0);
        callData.put("params_payload_id", paramsPayload.get("payload_id"));

        InterfaceResolution resolution = resolveInterfaceForCall(callData, sessionId, now);
        int callIndex = count("SELECT COUNT(*) FROM call_record WHERE session_id=?", sessionId) + 1;
        jdbc.update("""
                INSERT OR REPLACE INTO call_record
                (call_id, session_id, call_index, object_name, cmd_name, slot_id, slot_key,
                 service_name, class_name, method_name, display_name, description, thread_name,
                 args_json, raw_args_json, parameter_meta_json, params_json, params_fingerprint, params_summary,
                 params_preview, params_size, params_hash, params_truncated, params_payload_id, payload_status,
                 status, interface_id, discovery_enabled, interface_registered, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, 'ready',
                        'running', ?, ?, ?, ?, ?)
                """,
                callId,
                sessionId,
                callIndex,
                callData.get("object_name"),
                callData.get("cmd_name"),
                callData.get("slot_id"),
                callData.get("slot_key"),
                payload.get("serviceName"),
                payload.get("className"),
                payload.get("methodName"),
                payload.get("displayName"),
                callData.get("description"),
                payload.get("threadName"),
                Jsons.dumps(callData.get("raw_args")),
                Jsons.dumps(callData.get("raw_args")),
                Jsons.dumps(payload.getOrDefault("parameterMeta", List.of())),
                callData.get("params_fingerprint"),
                callData.get("params_summary"),
                callData.get("params_preview"),
                callData.get("params_size"),
                callData.get("params_hash"),
                callData.get("params_truncated"),
                callData.get("params_payload_id"),
                resolution.interfaceId,
                resolution.discoveryEnabled,
                resolution.interfaceRegistered,
                now,
                now);
        Map<String, Object> matched = matchBreakpoint(callData, sessionId);
        if (matched != null) {
            waitManager.create(callId);
            jdbc.update("""
                    UPDATE call_record
                    SET status='paused', breakpoint_id=?, breakpoint_name=?, updated_at=?
                    WHERE call_id=?
                    """, matched.get("id"), matched.get("name"), now, callId);
            applyBreakpointHit(matched, now);
            return mapOf(
                    "success", true,
                    "callIndex", callIndex,
                    "action", "pause",
                    "reason", "matched breakpoint",
                    "waitTimeoutMs", 300000,
                    "breakpointId", matched.get("id"),
                    "breakpointName", matched.get("name"),
                    "interfaceId", resolution.interfaceId);
        }
        return mapOf("success", true, "callIndex", callIndex, "action", "continue", "interfaceId",
                resolution.interfaceId);
    }

    public synchronized Map<String, Object> afterCall(Map<String, Object> payload) {
        Map<String, Object> row = first("SELECT * FROM call_record WHERE call_id=?", payload.get("callId"));
        if (row == null) {
            return mapOf("success", true, "ignored", true);
        }
        String now = TextUtil.nowIso();
        boolean success = bool(payload.get("success"));
        Map<String, Object> resultPayload = payloadService.savePayload(str(row.get("session_id")), str(payload.get("callId")),
                "result", payload.get("result"), now);
        jdbc.update("""
                UPDATE call_record
                SET result_json=NULL, result_summary=?, result_preview=?, result_size=?, result_hash=?,
                    result_truncated=?, result_payload_id=?, payload_status='ready',
                    success=?, exception_type=?, exception_message=?,
                    cost_ms=?, status=?, finished_at=?, updated_at=?
                WHERE call_id=?
                """,
                resultPayload.get("summary"),
                resultPayload.get("preview"),
                resultPayload.get("size"),
                resultPayload.get("hash"),
                bool(resultPayload.get("truncated")) ? 1 : 0,
                resultPayload.get("payload_id"),
                success ? 1 : 0,
                payload.get("exceptionType"),
                payload.get("exceptionMessage"),
                payload.get("costMs"),
                success ? "finished" : "exception",
                now,
                now,
                payload.get("callId"));
        if (intValue(row.get("discovery_enabled"), 0) == 1 && row.get("interface_id") != null) {
            updateParamSampleResult(row, payload, now, str(resultPayload.get("payload_id")));
            updateInterfaceStats(row, payload, now);
        }
        return mapOf("success", true);
    }

    public synchronized Map<String, Object> continueCall(String callId) {
        Map<String, Object> row = first("SELECT status FROM call_record WHERE call_id=?", callId);
        if (row == null) {
            return mapOf("success", false, "message", "call not found", "released", false);
        }
        if (!"paused".equals(row.get("status"))) {
            return mapOf("success", false, "message", "call is not paused", "released", false);
        }
        String now = TextUtil.nowIso();
        boolean released = waitManager.continueOne(callId);
        jdbc.update("UPDATE call_record SET status='continued', continued_at=?, updated_at=? WHERE call_id=?",
                now, now, callId);
        return mapOf("success", true, "released", released);
    }

    public synchronized Map<String, Object> continueAllCalls() {
        int released = waitManager.continueAll();
        String now = TextUtil.nowIso();
        if (sessionId != null) {
            jdbc.update("""
                    UPDATE call_record
                    SET status='continued', continued_at=?, updated_at=?
                    WHERE session_id=? AND status='paused'
                    """, now, now, sessionId);
        }
        return mapOf("success", true, "releasedCount", released);
    }

    public Map<String, Object> listCalls(String selectedSessionId, String objectName, String keyword, String status,
            String sortBy, String sortOrder, Object pageValue, Object pageSizeValue) {
        String sid = selectedSessionId == null || selectedSessionId.isBlank() ? sessionId : selectedSessionId;
        int page = pageValue(pageValue);
        int pageSize = pageSizeValue(pageSizeValue);
        if (sid == null) {
            return mapOf("success", true, "items", List.of(), "page", page, "pageSize", pageSize, "total", 0);
        }
        Query where = callListWhere(sid, objectName, keyword, status);
        int total = count("SELECT COUNT(*) FROM call_record c " + where.sql, where.args.toArray());
        List<Object> args = new ArrayList<>(where.args);
        args.add(pageSize);
        args.add((page - 1) * pageSize);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT c.id, c.call_id, c.session_id, c.call_index, c.object_name, c.cmd_name,
                       c.slot_id, c.slot_key, c.status, c.breakpoint_id, c.breakpoint_name,
                       c.description, c.exception_type, c.exception_message,
                       c.cost_ms, c.created_at, c.created_at AS started_at, c.finished_at, c.updated_at,
                       c.interface_id, c.discovery_enabled, c.interface_registered,
                       c.params_summary, c.result_summary, c.params_size, c.result_size,
                       c.params_hash, c.result_hash, c.params_truncated, c.result_truncated,
                       c.payload_status, i.interface_alias
                FROM call_record c
                LEFT JOIN discovered_interface i ON c.interface_id=i.id
                """ + where.sql + " " + callListOrder(sortBy, sortOrder) + " LIMIT ? OFFSET ?",
                args.toArray());
        return mapOf("success", true, "items", normalizeRows(rows), "page", page, "pageSize", pageSize, "total",
                total);
    }

    public Map<String, Object> listInterfaces(String selectedSessionId, String objectName, String keyword, String status,
            String sortBy, String sortOrder, Object pageValue, Object pageSizeValue) {
        String sid = selectedSessionId == null || selectedSessionId.isBlank() ? sessionId : selectedSessionId;
        int page = pageValue(pageValue);
        int pageSize = pageSizeValue(pageSizeValue);
        if (sid == null) {
            return mapOf("success", true, "items", List.of(), "page", page, "pageSize", pageSize, "total", 0);
        }
        Query where = interfaceListWhere(sid, objectName, keyword, status);
        int total = count("SELECT COUNT(*) FROM discovered_interface " + where.sql, where.args.toArray());
        List<Object> args = new ArrayList<>(where.args);
        args.add(pageSize);
        args.add((page - 1) * pageSize);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT id, session_id, object_name, cmd_name, slot_id, slot_key, service_name,
                       class_name, method_name, interface_alias, display_name, description,
                       latest_params_fingerprint, params_sample_count, params_summary,
                       first_seen_at, last_seen_at, call_count, success_count, exception_count,
                       avg_cost_ms, max_cost_ms, min_cost_ms, created_at, updated_at
                FROM discovered_interface
                """ + where.sql + " " + interfaceListOrder(sortBy, sortOrder) + " LIMIT ? OFFSET ?",
                args.toArray());
        return mapOf("success", true, "items", normalizeRows(rows), "page", page, "pageSize", pageSize, "total",
                total);
    }

    public List<Map<String, Object>> listSessions() {
        return jdbc.queryForList("""
                SELECT s.*,
                    (SELECT COUNT(*) FROM call_record c WHERE c.session_id=s.id) AS call_count,
                    (SELECT COUNT(*) FROM discovered_interface i WHERE i.session_id=s.id) AS interface_count,
                    (SELECT COUNT(*) FROM breakpoint b WHERE b.session_id=s.id) AS breakpoint_count,
                    (SELECT COUNT(*) FROM call_record c WHERE c.session_id=s.id AND c.status='exception') AS exception_count
                FROM debug_session s ORDER BY s.created_at DESC
                """);
    }

    public Map<String, Object> callDetail(String callId) {
        Map<String, Object> row = first("""
                SELECT id, call_id, session_id, call_index, object_name, cmd_name, slot_id, slot_key,
                       service_name, class_name, method_name, display_name, description, thread_name,
                       parameter_meta_json, params_fingerprint, params_summary, params_preview, params_size,
                       params_hash, params_truncated, params_payload_id,
                       result_summary, result_preview, result_size, result_hash, result_truncated,
                       result_payload_id, payload_status, success, exception_type, exception_message,
                       cost_ms, status, breakpoint_id, breakpoint_name, interface_id, discovery_enabled,
                       interface_registered, continued_at, finished_at, created_at, updated_at
                FROM call_record
                WHERE call_id=?
                """, callId);
        if (row == null) {
            return null;
        }
        return normalize(row);
    }

    public Map<String, Object> interfaceDetail(String interfaceId) {
        Map<String, Object> row = first("""
                SELECT id, session_id, object_name, cmd_name, slot_id, slot_key, service_name,
                       class_name, method_name, interface_alias, display_name, description,
                       latest_params_fingerprint, params_sample_count, params_summary,
                       first_seen_at, last_seen_at, call_count, success_count, exception_count,
                       avg_cost_ms, max_cost_ms, min_cost_ms, created_at, updated_at
                FROM discovered_interface WHERE id=?
                """, interfaceId);
        if (row == null) {
            return null;
        }
        Map<String, Object> item = normalize(row);
        item.put("samples", interfaceSamples(interfaceId, 10, 0).get("items"));
        return item;
    }

    public Map<String, Object> interfaceSamples(String interfaceId, Object limitValue, Object offsetValue) {
        int limit = Math.min(Math.max(intValue(limitValue, 10), 1), 50);
        int offset = Math.max(intValue(offsetValue, 0), 0);
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT s.id, s.interface_id, s.call_id, s.object_name, s.cmd_name, s.slot_id, s.slot_key,
                       s.params_fingerprint, s.params_hash, s.params_summary, s.params_size, s.params_payload_id,
                       COALESCE(NULLIF(s.params_preview, ''), c.params_preview) AS params_preview,
                       COALESCE(s.params_truncated, c.params_truncated, 0) AS params_truncated,
                       s.result_summary, s.result_size, s.result_payload_id, s.success, s.cost_ms,
                       s.first_seen_at, s.last_seen_at, s.created_at, s.updated_at, s.seen_count
                FROM interface_param_sample s
                LEFT JOIN call_record c ON s.call_id=c.call_id
                WHERE s.interface_id=?
                ORDER BY s.last_seen_at DESC, s.created_at DESC
                LIMIT ? OFFSET ?
                """, interfaceId, limit, offset);
        List<Map<String, Object>> items = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> sample = normalize(row);
            sample.put("sampleId", sample.get("id"));
            String payloadId = str(firstNonNull(sample.get("params_payload_id"), sample.get("paramsPayloadId")));
            sample.put("paramsPayloadId", payloadId);
            if (str(sample.get("params_preview")).isBlank() && !payloadId.isBlank()) {
                Map<String, Object> chunk = payloadService.payloadChunkById(payloadId, 0, 8192);
                if (chunk != null) {
                    sample.put("params_preview", chunk.get("content"));
                    sample.put("paramsPreview", chunk.get("content"));
                    sample.put("params_truncated", bool(chunk.get("hasMore")));
                }
            }
            sample.put("paramsPreview", firstNonNull(sample.get("params_preview"), sample.get("paramsPreview"), ""));
            sample.put("paramsSize", firstNonNull(sample.get("params_size"), sample.get("paramsSize"), 0));
            sample.put("paramsHash", firstNonNull(sample.get("params_hash"), sample.get("paramsHash"),
                    sample.get("params_fingerprint"), ""));
            sample.put("paramsTruncated", bool(firstNonNull(sample.get("params_truncated"), sample.get("paramsTruncated"))));
            items.add(sample);
        }
        return mapOf("success", true, "items", items, "limit", limit, "offset", offset);
    }

    public Map<String, Object> groupedCalls(String selectedSessionId) {
        String sid = selectedSessionId == null || selectedSessionId.isBlank() ? sessionId : selectedSessionId;
        if (sid == null) {
            return mapOf("success", true, "groups", List.of());
        }
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT object_name,
                       COUNT(*) AS callCount,
                       SUM(CASE WHEN breakpoint_id IS NOT NULL AND breakpoint_id<>'' THEN 1 ELSE 0 END) AS hitCount,
                       SUM(CASE WHEN status='paused' THEN 1 ELSE 0 END) AS pausedCount,
                       SUM(CASE WHEN status='exception' THEN 1 ELSE 0 END) AS exceptionCount,
                       AVG(cost_ms) AS avgCostMs
                FROM call_record
                WHERE session_id=?
                GROUP BY object_name
                ORDER BY object_name ASC
                """, sid);
        for (Map<String, Object> row : rows) {
            row.put("objectName", firstNonNull(row.get("objectName"), row.get("object_name")));
        }
        return mapOf("success", true, "groups", rows);
    }

    public Map<String, Object> groupedInterfaces(String selectedSessionId) {
        String sid = selectedSessionId == null || selectedSessionId.isBlank() ? sessionId : selectedSessionId;
        if (sid == null) {
            return mapOf("success", true, "groups", List.of());
        }
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT object_name,
                       COUNT(*) AS interfaceCount,
                       SUM(COALESCE(call_count, 0)) AS callCount,
                       SUM(COALESCE(success_count, 0)) AS successCount,
                       SUM(COALESCE(exception_count, 0)) AS exceptionCount,
                       AVG(avg_cost_ms) AS avgCostMs
                FROM discovered_interface
                WHERE session_id=?
                GROUP BY object_name
                ORDER BY object_name ASC
                """, sid);
        for (Map<String, Object> row : rows) {
            row.put("objectName", firstNonNull(row.get("objectName"), row.get("object_name")));
        }
        return mapOf("success", true, "groups", rows);
    }

    public synchronized Map<String, Object> registerInterfaceFromCall(String callId) {
        Map<String, Object> row = first("SELECT * FROM call_record WHERE call_id=?", callId);
        if (row == null) {
            return mapOf("success", false, "message", "call not found");
        }
        Map<String, Object> call = normalize(row);
        Map<String, Object> callData = callDataFromRecord(call);
        String sid = str(call.get("session_id"));
        String now = TextUtil.nowIso();
        String interfaceId = upsertInterface(callData, sid, now);
        int updated = jdbc.update("""
                UPDATE call_record
                SET interface_id=?, discovery_enabled=1, interface_registered=1, updated_at=?
                WHERE session_id=? AND object_name=? AND cmd_name=?
                """, interfaceId, now, sid, call.get("object_name"), call.get("cmd_name"));
        recalculateInterfaceStats(interfaceId, now);
        int total = count("SELECT COUNT(*) FROM call_record WHERE interface_id=?", interfaceId);
        return mapOf("success", true, "interfaceId", interfaceId, "updatedCallCount", updated,
                "totalInterfaceCallCount", total);
    }

    public List<Map<String, Object>> listInterfaceBreakpoints(String interfaceId) {
        Map<String, Object> item = first("SELECT * FROM discovered_interface WHERE id=?", interfaceId);
        if (item == null) {
            return null;
        }
        return normalizeRows(jdbc.queryForList("""
                SELECT * FROM breakpoint
                WHERE session_id=? AND object_name=? AND cmd_name=?
                ORDER BY created_at DESC
                """, item.get("session_id"), item.get("object_name"), item.get("cmd_name")));
    }

    public synchronized Map<String, Object> setInterfaceLocked(boolean locked) {
        String now = TextUtil.nowIso();
        jdbc.update("""
                INSERT INTO app_setting (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at
                """, INTERFACE_LOCK_SETTING, locked ? "1" : "0", now);
        return stateResponse(mapOf("success", true, "interfaceLocked", locked));
    }

    public boolean interfaceLocked() {
        return "1".equals(settingValue(INTERFACE_LOCK_SETTING));
    }

    public List<Map<String, Object>> listBreakpoints(String selectedSessionId) {
        String sid = selectedSessionId == null || selectedSessionId.isBlank() ? sessionId : selectedSessionId;
        if (sid == null) {
            return List.of();
        }
        return normalizeRows(jdbc.queryForList(
                "SELECT * FROM breakpoint WHERE session_id=? ORDER BY created_at DESC", sid));
    }

    public synchronized Map<String, Object> createBreakpoint(Map<String, Object> data) {
        String sid = str(firstNonNull(data.get("sessionId"), sessionId));
        if (sid.isBlank()) {
            return mapOf("success", false, "message", "请先新建或选择会话");
        }
        String now = TextUtil.nowIso();
        String breakpointId = "bp-" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        String objectName = strOr(data.get("objectName"), UNCATEGORIZED_OBJECT);
        String cmdName = strOr(data.get("cmdName"), UNKNOWN_COMMAND);
        String matchMode = strOr(data.get("matchMode"), "command_only");
        Integer requestedSlotId = normalizeSlotId(data.get("slotId"));
        Integer slotId = "command_only".equals(matchMode) ? null : requestedSlotId;
        String slotKey = "command_only".equals(matchMode) ? null : normalizedSlotKey(slotId, str(data.get("slotKey")));
        Object paramsFingerprint = firstNonNull(data.get("paramsFingerprint"), data.get("params_fingerprint"));
        Object paramsSummary = firstNonNull(data.get("paramsSummary"), data.get("params_summary"));
        Object paramsPayloadId = firstNonNull(data.get("paramsPayloadId"), data.get("params_payload_id"));
        Object conditions = firstNonNull(data.get("conditions"), data.get("conditions_json"), List.of());
        Object conditionFields = firstNonNull(data.get("conditionFields"), data.get("condition_fields"), Map.of());
        Map<String, Object> normalized = new LinkedHashMap<>(data);
        normalized.put("sessionId", sid);
        normalized.put("objectName", objectName);
        normalized.put("cmdName", cmdName);
        normalized.put("matchMode", matchMode);
        normalized.put("slotId", slotId);
        normalized.put("slotKey", slotKey);
        normalized.put("paramsFingerprint", paramsFingerprint);
        normalized.put("conditions", conditions);
        if (findDuplicateBreakpoint(normalized) != null) {
            return mapOf(
                    "success", false,
                    "code", isCommandBreakpoint(matchMode) ? "DUPLICATE_COMMAND_BREAKPOINT" : "DUPLICATE_CONDITION_BREAKPOINT",
                    "message", "breakpoint already exists");
        }
        jdbc.update("""
                INSERT INTO breakpoint
                (id, name, enabled, scope, session_id, object_name, cmd_name, slot_id, slot_key, match_mode,
                 params_fingerprint, params_hash, params_summary, params_payload_id, params_snapshot_json,
                 condition_fields_json, conditions_json, condition_json, hit_mode, hit_count,
                 hit_limit, source_type, source_session_id, source_interface_id, source_call_id,
                 service_name, class_name, method_name, display_name, created_at, updated_at)
                VALUES (?, ?, ?, 'session', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, NULL, ?, 0,
                        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                breakpointId,
                strOr(data.get("name"), objectName + " " + cmdName),
                bool(firstNonNull(data.get("enabled"), true)) ? 1 : 0,
                sid,
                objectName,
                cmdName,
                slotId,
                slotKey,
                matchMode,
                paramsFingerprint,
                paramsFingerprint,
                paramsSummary,
                paramsPayloadId,
                Jsons.dumps(conditionFields),
                Jsons.dumps(conditions),
                strOr(data.get("hitMode"), "always"),
                data.get("hitLimit"),
                data.get("sourceType"),
                firstNonNull(data.get("sourceSessionId"), sid),
                data.get("sourceInterfaceId"),
                data.get("sourceCallId"),
                data.get("serviceName"),
                data.get("className"),
                data.get("methodName"),
                data.get("displayName"),
                now,
                now);
        int disabled = 0;
        if (isConditionBreakpoint(matchMode)) {
            disabled = jdbc.update("""
                    UPDATE breakpoint SET enabled=0, updated_at=?
                    WHERE session_id=? AND object_name=? AND cmd_name=? AND COALESCE(match_mode, 'command_only')='command_only'
                    """, now, sid, objectName, cmdName);
        }
        return mapOf("success", true, "breakpointId", breakpointId, "disabledCommandBreakpointCount", disabled);
    }

    public synchronized Map<String, Object> declareBreakpointRule(Map<String, Object> payload) {
        String sid = str(firstNonNull(payload.get("sessionId"), sessionId));
        if (sid.isBlank()) {
            return agentRuleError("请先新建或选择会话");
        }
        Map<String, Object> target = Jsons.object(payload.get("target"));
        Map<String, Object> match = Jsons.object(payload.get("match"));
        String objectName = strOr(firstNonNull(target.get("object"), target.get("objectName")), UNCATEGORIZED_OBJECT);
        String cmdName = strOr(firstNonNull(target.get("command"), target.get("cmdName")), UNKNOWN_COMMAND);
        String displayName = str(firstNonNull(target.get("display_name"), target.get("displayName")));
        String matchType = strOr(match.get("type"), "interface");
        String matchMode = "parameters".equals(matchType) ? "params_condition" : "command_only";
        Object conditions = "params_condition".equals(matchMode)
                ? normalizeAgentConditions(match.get("conditions"))
                : List.of();
        Map<String, Object> ruleData = mapOf(
                "sessionId", sid,
                "objectName", objectName,
                "cmdName", cmdName,
                "displayName", displayName,
                "name", displayName.isBlank() ? objectName + " " + cmdName : displayName,
                "enabled", true,
                "matchMode", matchMode,
                "conditions", conditions,
                "sourceType", "agent",
                "sourceSessionId", sid,
                "hitMode", "always");
        Map<String, Object> duplicate = findDuplicateBreakpoint(ruleData);
        String ruleId;
        if (duplicate != null) {
            ruleId = str(duplicate.get("id"));
            jdbc.update("UPDATE breakpoint SET enabled=1, updated_at=? WHERE id=?", TextUtil.nowIso(), ruleId);
        } else {
            Map<String, Object> created = createBreakpoint(ruleData);
            if (!Boolean.TRUE.equals(created.get("success"))) {
                return agentRuleError(strOr(created.get("message"), "断点规则注册失败"));
            }
            ruleId = str(created.get("breakpointId"));
        }
        return agentRuleResponse(ruleId, objectName, cmdName, observationHint(sid, objectName, cmdName));
    }

    private Map<String, Object> agentRuleResponse(String ruleId, String objectName, String cmdName,
            Map<String, Object> observationHint) {
        return mapOf(
                "ok", true,
                "status", "armed",
                "breakpoint_rule_id", ruleId,
                "message", "断点规则已注册；目标调用出现时会自动暂停。",
                "meta", mapOf("observation_hint", observationHint),
                "entities", List.of(mapOf(
                        "type", "breakpoint_rule",
                        "id", ruleId,
                        "label", objectName + "." + cmdName,
                        "status", "armed")));
    }

    private Map<String, Object> agentRuleError(String message) {
        return mapOf(
                "ok", false,
                "status", "invalid_request",
                "message", message,
                "entities", List.of());
    }

    private Map<String, Object> observationHint(String sid, String objectName, String cmdName) {
        int count = count("SELECT COUNT(*) FROM call_record WHERE session_id=? AND object_name=? AND cmd_name=?",
                sid, objectName, cmdName);
        String state = count > 0 ? "observed" : "unobserved";
        String message = count > 0
                ? "当前会话已经见过匹配调用；规则已生效。"
                : "当前尚未见过匹配调用；规则已生效。";
        return mapOf("state", state, "message", message);
    }

    private List<Map<String, Object>> normalizeAgentConditions(Object rawConditions) {
        List<Map<String, Object>> result = new ArrayList<>();
        List<?> conditions = rawConditions instanceof List<?> list ? list : List.of();
        for (Object item : conditions) {
            Map<String, Object> condition = Jsons.object(item);
            String path = str(condition.get("path"));
            if (path.startsWith("parameters.")) {
                path = "params." + path.substring("parameters.".length());
            }
            result.add(mapOf(
                    "path", path,
                    "operator", firstNonNull(condition.get("operator"), condition.get("op"), "eq"),
                    "value", condition.get("value")));
        }
        return result;
    }

    public Map<String, Object> breakpointFromInterface(String interfaceId, Map<String, Object> body) {
        Map<String, Object> row = first("SELECT * FROM discovered_interface WHERE id=?", interfaceId);
        if (row == null) {
            return mapOf("success", false, "message", "interface not found");
        }
        Map<String, Object> item = normalize(row);
        String matchMode = strOr(body.get("matchMode"), "command_only");
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("name", firstNonNull(body.get("name"),
                str(item.get("interface_alias")).isBlank() ? item.get("object_name") + " " + item.get("cmd_name")
                        : item.get("interface_alias")));
        data.put("enabled", firstNonNull(body.get("enabled"), true));
        data.put("sessionId", item.get("session_id"));
        data.put("objectName", item.get("object_name"));
        data.put("cmdName", item.get("cmd_name"));
        data.put("matchMode", matchMode);
        if ("params_snapshot".equals(matchMode)) {
            data.put("paramsFingerprint", item.get("latest_params_fingerprint"));
            data.put("paramsSummary", item.get("params_summary"));
        }
        data.put("hitMode", strOr(body.get("hitMode"), "always"));
        data.put("sourceType", "interface");
        data.put("sourceSessionId", item.get("session_id"));
        data.put("sourceInterfaceId", interfaceId);
        data.put("serviceName", item.get("service_name"));
        data.put("className", item.get("class_name"));
        data.put("methodName", item.get("method_name"));
        data.put("displayName", item.get("display_name"));
        return createBreakpoint(data);
    }

    public Map<String, Object> breakpointFromCall(String callId, Map<String, Object> body) {
        Map<String, Object> row = first("SELECT * FROM call_record WHERE call_id=?", callId);
        if (row == null) {
            return mapOf("success", false, "message", "call not found");
        }
        Map<String, Object> call = normalize(row);
        String matchMode = strOr(body.get("matchMode"), "command_only");
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("name", firstNonNull(body.get("name"), call.get("object_name") + " " + call.get("cmd_name")));
        data.put("enabled", firstNonNull(body.get("enabled"), true));
        data.put("sessionId", call.get("session_id"));
        data.put("objectName", call.get("object_name"));
        data.put("cmdName", call.get("cmd_name"));
        data.put("matchMode", matchMode);
        if (!"command_only".equals(matchMode)) {
            data.put("slotId", call.get("slot_id"));
            data.put("slotKey", call.get("slot_key"));
            data.put("paramsFingerprint", call.get("params_fingerprint"));
            data.put("paramsSummary", call.get("params_summary"));
            data.put("paramsPayloadId", call.get("params_payload_id"));
        }
        data.put("hitMode", strOr(body.get("hitMode"), "always"));
        data.put("sourceType", "call");
        data.put("sourceSessionId", call.get("session_id"));
        data.put("sourceInterfaceId", call.get("interface_id"));
        data.put("sourceCallId", callId);
        data.put("serviceName", call.get("service_name"));
        data.put("className", call.get("class_name"));
        data.put("methodName", call.get("method_name"));
        data.put("displayName", call.get("display_name"));
        return createBreakpoint(data);
    }

    public synchronized Map<String, Object> updateInterfaceAlias(String interfaceId, String alias) {
        String now = TextUtil.nowIso();
        int updated = jdbc.update("UPDATE discovered_interface SET interface_alias=?, updated_at=? WHERE id=?",
                alias == null ? "" : alias, now, interfaceId);
        return updated > 0 ? mapOf("success", true) : mapOf("success", false, "message", "not found");
    }

    public synchronized void deleteBreakpoint(String breakpointId) {
        jdbc.update("DELETE FROM breakpoint WHERE id=?", breakpointId);
    }

    public synchronized void setBreakpointEnabled(String breakpointId, boolean enabled) {
        jdbc.update("UPDATE breakpoint SET enabled=?, updated_at=? WHERE id=?", enabled ? 1 : 0, TextUtil.nowIso(),
                breakpointId);
    }

    public JdbcTemplate jdbc() {
        return jdbc;
    }

    private InterfaceResolution resolveInterfaceForCall(Map<String, Object> callData, String sid, String now) {
        String existing = findInterfaceId(callData, sid);
        if (existing != null) {
            return new InterfaceResolution(upsertInterface(callData, sid, now), 1, 1);
        }
        if (interfaceLocked()) {
            return new InterfaceResolution(null, 0, 0);
        }
        return new InterfaceResolution(upsertInterface(callData, sid, now), 1, 1);
    }

    private String findInterfaceId(Map<String, Object> callData, String sid) {
        Map<String, Object> row = first(
                "SELECT id FROM discovered_interface WHERE session_id=? AND object_name=? AND cmd_name=?",
                sid, callData.get("object_name"), callData.get("cmd_name"));
        return row == null ? null : str(row.get("id"));
    }

    private String upsertInterface(Map<String, Object> callData, String sid, String now) {
        Map<String, Object> existing = first(
                "SELECT id FROM discovered_interface WHERE session_id=? AND object_name=? AND cmd_name=?",
                sid, callData.get("object_name"), callData.get("cmd_name"));
        String interfaceId = existing == null
                ? UUID.nameUUIDFromBytes((sid + "|" + callData.get("object_name") + "|" + callData.get("cmd_name"))
                        .getBytes(StandardCharsets.UTF_8)).toString().replace("-", "")
                : str(existing.get("id"));
        Map<String, Object> schema = paramsSchema(Jsons.object(callData.get("params")));
        boolean newSample = upsertParamSample(interfaceId, callData, now);
        if (existing != null) {
            jdbc.update("""
                    UPDATE discovered_interface
                    SET description=?, latest_params_json=NULL, latest_params_fingerprint=?, params_schema_json=?,
                        parameter_schema_json=?, sample_args_json=?, params_summary=?,
                        service_name=?, class_name=?, method_name=?, display_name=?,
                        last_seen_at=?, call_count=COALESCE(call_count,0)+1,
                        params_sample_count=COALESCE(params_sample_count,0)+?, updated_at=?
                    WHERE id=?
                    """,
                    callData.get("description"),
                    callData.get("params_fingerprint"),
                    Jsons.dumps(schema),
                    Jsons.dumps(schema),
                    Jsons.dumps(sampleArgsPayload(callData, now)),
                    callData.get("params_summary"),
                    callData.get("service_name"),
                    callData.get("class_name"),
                    callData.get("method_name"),
                    callData.get("display_name"),
                    now,
                    newSample ? 1 : 0,
                    now,
                    interfaceId);
            return interfaceId;
        }
        jdbc.update("""
                INSERT INTO discovered_interface
                (id, session_id, object_name, cmd_name, slot_id, slot_key, service_name, class_name, method_name,
                 interface_key, http_method, request_uri, query_signature, body_signature, content_type,
                 interface_alias, display_name, description, parameter_schema_json, params_schema_json,
                 sample_args_json, latest_params_json, latest_params_fingerprint, params_sample_count, params_summary,
                 first_seen_at, last_seen_at, call_count, success_count, exception_count, created_at, updated_at)
                VALUES (?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?, 'DEBUG', ?, '', ?, '',
                        NULL, ?, ?, ?, ?, ?, NULL, ?, 1, ?, ?, ?, 1, 0, 0, ?, ?)
                """,
                interfaceId,
                sid,
                callData.get("object_name"),
                callData.get("cmd_name"),
                callData.get("service_name"),
                callData.get("class_name"),
                callData.get("method_name"),
                callData.get("object_name") + " " + callData.get("cmd_name"),
                callData.get("cmd_name"),
                callData.get("params_fingerprint"),
                callData.get("display_name"),
                callData.get("description"),
                Jsons.dumps(schema),
                Jsons.dumps(schema),
                Jsons.dumps(sampleArgsPayload(callData, now)),
                callData.get("params_fingerprint"),
                callData.get("params_summary"),
                now,
                now,
                now,
                now);
        return interfaceId;
    }

    private boolean upsertParamSample(String interfaceId, Map<String, Object> callData, String now) {
        String sampleId = UUID.nameUUIDFromBytes((interfaceId + "|" + callData.get("slot_key") + "|"
                + callData.get("params_fingerprint")).getBytes(StandardCharsets.UTF_8)).toString().replace("-", "");
        Map<String, Object> existing = first(
                "SELECT id FROM interface_param_sample WHERE interface_id=? AND slot_key=? AND params_fingerprint=?",
                interfaceId, callData.get("slot_key"), callData.get("params_fingerprint"));
        if (existing != null) {
            jdbc.update("""
                    UPDATE interface_param_sample
                    SET call_id=?, object_name=?, cmd_name=?, slot_id=?, args_json=?, params_json=NULL,
                        params_hash=?, params_summary=?, params_preview=?, params_truncated=?,
                        params_size=?, params_payload_id=?,
                        last_seen_at=?, updated_at=?, seen_count=COALESCE(seen_count,0)+1
                    WHERE id=?
                    """,
                    callData.get("call_id"),
                    callData.get("object_name"),
                    callData.get("cmd_name"),
                    callData.get("slot_id"),
                    Jsons.dumps(callData.get("raw_args")),
                    callData.get("params_hash"),
                    callData.get("params_summary"),
                    callData.get("params_preview"),
                    callData.get("params_truncated"),
                    callData.get("params_size"),
                    callData.get("params_payload_id"),
                    now,
                    now,
                    existing.get("id"));
            return false;
        }
        jdbc.update("""
                INSERT INTO interface_param_sample
                (id, interface_id, call_id, object_name, cmd_name, slot_id, slot_key, args_json,
                 params_fingerprint, params_hash, params_summary, params_preview, params_truncated,
                 params_size, params_payload_id, params_json,
                 first_seen_at, last_seen_at, created_at, updated_at, seen_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, 1)
                """,
                sampleId,
                interfaceId,
                callData.get("call_id"),
                callData.get("object_name"),
                callData.get("cmd_name"),
                callData.get("slot_id"),
                callData.get("slot_key"),
                Jsons.dumps(callData.get("raw_args")),
                callData.get("params_fingerprint"),
                callData.get("params_hash"),
                callData.get("params_summary"),
                callData.get("params_preview"),
                callData.get("params_truncated"),
                callData.get("params_size"),
                callData.get("params_payload_id"),
                now,
                now,
                now,
                now);
        return true;
    }

    private void updateParamSampleResult(Map<String, Object> callRow, Map<String, Object> payload, String now,
            String resultPayloadId) {
        jdbc.update("""
                UPDATE interface_param_sample
                SET result_json=NULL, result_summary=?, result_size=?, result_payload_id=?,
                    success=?, cost_ms=?, updated_at=?
                WHERE interface_id=? AND slot_key=? AND params_fingerprint=?
                """,
                payloadService.payloadMeta(payload.get("result")).get("summary"),
                payloadService.payloadMeta(payload.get("result")).get("size"),
                resultPayloadId,
                bool(payload.get("success")) ? 1 : 0,
                payload.get("costMs"),
                now,
                callRow.get("interface_id"),
                callRow.get("slot_key"),
                callRow.get("params_fingerprint"));
    }

    private void updateInterfaceStats(Map<String, Object> callRow, Map<String, Object> payload, String now) {
        jdbc.update("""
                UPDATE discovered_interface
                SET success_count=COALESCE(success_count,0)+?,
                    exception_count=COALESCE(exception_count,0)+?,
                    avg_cost_ms=(
                      SELECT AVG(cost_ms) FROM call_record
                      WHERE interface_id=? AND cost_ms IS NOT NULL AND status IN ('finished','exception')
                    ),
                    max_cost_ms=(
                      SELECT MAX(cost_ms) FROM call_record
                      WHERE interface_id=? AND cost_ms IS NOT NULL AND status IN ('finished','exception')
                    ),
                    min_cost_ms=(
                      SELECT MIN(cost_ms) FROM call_record
                      WHERE interface_id=? AND cost_ms IS NOT NULL AND status IN ('finished','exception')
                    ),
                    updated_at=?
                WHERE id=?
                """,
                bool(payload.get("success")) ? 1 : 0,
                bool(payload.get("success")) ? 0 : 1,
                callRow.get("interface_id"),
                callRow.get("interface_id"),
                callRow.get("interface_id"),
                now,
                callRow.get("interface_id"));
    }

    private Map<String, Object> matchBreakpoint(Map<String, Object> callData, String sid) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT * FROM breakpoint
                WHERE enabled=1 AND session_id=? AND object_name=? AND cmd_name=?
                ORDER BY created_at ASC
                """, sid, callData.get("object_name"), callData.get("cmd_name"));
        for (Map<String, Object> row : rows) {
            Map<String, Object> item = normalize(row);
            if (breakpointMatches(item, callData)) {
                if (shouldPause(item)) {
                    return item;
                }
                incrementBreakpointCount(item, TextUtil.nowIso());
            }
        }
        return null;
    }

    private boolean breakpointMatches(Map<String, Object> item, Map<String, Object> callData) {
        String matchMode = strOr(item.get("match_mode"), "command_only");
        if ("command_only".equals(matchMode)) {
            return true;
        }
        String bpSlotKey = normalizedSlotKey(normalizeSlotId(item.get("slot_id")), str(item.get("slot_key")));
        if (bpSlotKey != null && !bpSlotKey.equals(callData.get("slot_key"))) {
            return false;
        }
        if ("params_snapshot".equals(matchMode)) {
            return str(item.get("params_fingerprint")).equals(str(callData.get("params_fingerprint")));
        }
        if ("params_condition".equals(matchMode)) {
            return conditionsMatch(item.get("conditions"), breakpointMatchParams(callData));
        }
        return false;
    }

    private boolean conditionsMatch(Object rawConditions, Map<String, Object> params) {
        Object raw = rawConditions;
        if (raw instanceof String text) {
            raw = Jsons.loads(text, List.of());
        }
        List<?> conditions = raw instanceof List<?> list ? list : List.of();
        for (Object item : conditions) {
            Map<String, Object> condition = Jsons.object(item);
            String key = str(condition.get("path")).replaceFirst("^params\\.", "");
            String op = strOr(condition.get("operator"), "eq");
            Object expected = condition.get("value");
            boolean exists = params.containsKey(key);
            Object actual = params.get(key);
            if ("exists".equals(op) && !exists) {
                return false;
            }
            if ("eq".equals(op) && (!exists || !String.valueOf(actual).equals(String.valueOf(expected)))) {
                return false;
            }
        }
        return true;
    }

    private Map<String, Object> breakpointMatchParams(Map<String, Object> callData) {
        Map<String, Object> params = new LinkedHashMap<>(Jsons.object(callData.get("params")));
        params.put("slotId", callData.get("slot_id"));
        params.put("slotKey", callData.get("slot_key"));
        return params;
    }

    private void applyBreakpointHit(Map<String, Object> item, String now) {
        if ("once".equals(strOr(item.get("hit_mode"), "always"))) {
            jdbc.update("UPDATE breakpoint SET hit_count=COALESCE(hit_count,0)+1, enabled=0, updated_at=? WHERE id=?",
                    now, item.get("id"));
        } else {
            incrementBreakpointCount(item, now);
        }
    }

    private void incrementBreakpointCount(Map<String, Object> item, String now) {
        jdbc.update("UPDATE breakpoint SET hit_count=COALESCE(hit_count,0)+1, updated_at=? WHERE id=?",
                now, item.get("id"));
    }

    private boolean shouldPause(Map<String, Object> item) {
        String hitMode = strOr(item.get("hit_mode"), "always");
        if ("always".equals(hitMode) || "once".equals(hitMode)) {
            return true;
        }
        if ("hit_count".equals(hitMode)) {
            int limit = intValue(item.get("hit_limit"), 1);
            return intValue(item.get("hit_count"), 0) + 1 >= limit;
        }
        return true;
    }

    private Map<String, Object> callBusinessData(Map<String, Object> payload) {
        Map<String, Object> rawArgs = Jsons.object(firstNonNull(payload.get("rawArgs"), payload.get("args")));
        String objectName = nonEmpty(payload.get("objectName"));
        if (objectName == null) {
            objectName = firstNonEmpty(rawArgs.get("objectName"), payload.get("className"), UNCATEGORIZED_OBJECT);
        }
        String cmdName = nonEmpty(payload.get("cmdName"));
        if (cmdName == null) {
            cmdName = firstNonEmpty(rawArgs.get("cmdName"), payload.get("methodName"), UNKNOWN_COMMAND);
        }
        Integer slotId = normalizeSlotId(firstNonNull(payload.get("slotId"), rawArgs.get("slotId")));
        Map<String, Object> params = Jsons.object(firstNonNull(payload.get("params"), rawArgs.get("params")));
        String fingerprint = Jsons.dumps(params);
        Map<String, Object> normalizedArgs = new LinkedHashMap<>();
        normalizedArgs.put("objectName", objectName);
        normalizedArgs.put("cmdName", cmdName);
        normalizedArgs.put("slotId", slotId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("call_id", payload.get("callId"));
        result.put("object_name", objectName);
        result.put("cmd_name", cmdName);
        result.put("slot_id", slotId);
        result.put("slot_key", slotKey(slotId));
        result.put("description", strOr(payload.get("description"), ""));
        result.put("params", params);
        result.put("params_fingerprint", fingerprint);
        result.put("params_summary", "");
        result.put("raw_args", normalizedArgs);
        result.put("parameter_meta", payload.getOrDefault("parameterMeta", List.of()));
        result.put("service_name", payload.get("serviceName"));
        result.put("class_name", payload.get("className"));
        result.put("method_name", payload.get("methodName"));
        result.put("display_name", payload.get("displayName"));
        return result;
    }

    private Map<String, Object> sampleArgsPayload(Map<String, Object> callData, String createdAt) {
        Map<String, Object> sample = new LinkedHashMap<>();
        sample.put("callId", callData.get("call_id"));
        sample.put("objectName", callData.get("object_name"));
        sample.put("cmdName", callData.get("cmd_name"));
        sample.put("slotId", callData.get("slot_id"));
        sample.put("params", callData.get("params"));
        sample.put("createdAt", createdAt);
        sample.put("serviceName", callData.get("service_name"));
        sample.put("className", callData.get("class_name"));
        sample.put("methodName", callData.get("method_name"));
        sample.put("displayName", callData.get("display_name"));
        return sample;
    }

    private Map<String, Object> callDataFromRecord(Map<String, Object> call) {
        Map<String, Object> rawArgs = Jsons.object(call.get("raw_args"));
        Map<String, Object> params = Jsons.object(Jsons.loads(str(call.get("params_preview")), Map.of()));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("call_id", call.get("call_id"));
        result.put("object_name", call.get("object_name"));
        result.put("cmd_name", call.get("cmd_name"));
        result.put("slot_id", normalizeSlotId(call.get("slot_id")));
        result.put("slot_key", firstNonNull(call.get("slot_key"), slotKey(normalizeSlotId(call.get("slot_id")))));
        result.put("description", firstNonNull(call.get("description"), ""));
        result.put("params", params);
        result.put("params_fingerprint", call.get("params_fingerprint"));
        result.put("params_summary", call.get("params_summary"));
        result.put("params_preview", call.get("params_preview"));
        result.put("params_size", call.get("params_size"));
        result.put("params_hash", call.get("params_hash"));
        result.put("params_truncated", call.get("params_truncated"));
        result.put("params_payload_id", call.get("params_payload_id"));
        result.put("raw_args", rawArgs.isEmpty() ? mapOf("objectName", call.get("object_name"), "cmdName", call.get("cmd_name"),
                "slotId", call.get("slot_id")) : rawArgs);
        result.put("service_name", call.get("service_name"));
        result.put("class_name", call.get("class_name"));
        result.put("method_name", call.get("method_name"));
        result.put("display_name", call.get("display_name"));
        return result;
    }

    private void recalculateInterfaceStats(String interfaceId, String now) {
        Map<String, Object> stats = first("""
                SELECT COUNT(*) AS call_count,
                       SUM(CASE WHEN status='finished' THEN 1 ELSE 0 END) AS success_count,
                       SUM(CASE WHEN status='exception' THEN 1 ELSE 0 END) AS exception_count,
                       AVG(CASE WHEN status IN ('finished','exception') THEN cost_ms END) AS avg_cost_ms,
                       MAX(CASE WHEN status IN ('finished','exception') THEN cost_ms END) AS max_cost_ms,
                       MIN(CASE WHEN status IN ('finished','exception') THEN cost_ms END) AS min_cost_ms,
                       MIN(created_at) AS first_seen_at,
                       MAX(created_at) AS last_seen_at
                FROM call_record WHERE interface_id=?
                """, interfaceId);
        if (stats == null) {
            return;
        }
        jdbc.update("""
                UPDATE discovered_interface
                SET call_count=?, success_count=?, exception_count=?, avg_cost_ms=?,
                    max_cost_ms=?, min_cost_ms=?, first_seen_at=COALESCE(?, first_seen_at),
                    last_seen_at=COALESCE(?, last_seen_at), updated_at=?
                WHERE id=?
                """,
                stats.get("call_count"), stats.get("success_count"), stats.get("exception_count"),
                stats.get("avg_cost_ms"), stats.get("max_cost_ms"), stats.get("min_cost_ms"),
                stats.get("first_seen_at"), stats.get("last_seen_at"), now, interfaceId);
    }

    private Map<String, Object> paramsSchema(Map<String, Object> params) {
        Map<String, Object> schema = new LinkedHashMap<>();
        params.forEach((key, value) -> {
            Map<String, Object> field = new LinkedHashMap<>();
            field.put("type", value == null ? "null" : value.getClass().getSimpleName());
            schema.put(key, field);
        });
        return schema;
    }

    public List<Map<String, Object>> normalizeRows(List<Map<String, Object>> rows) {
        return rows.stream().map(this::normalize).toList();
    }

    public Map<String, Object> normalize(Map<String, Object> row) {
        Map<String, Object> result = new LinkedHashMap<>(row);
        for (String key : new ArrayList<>(result.keySet())) {
            if (key.endsWith("_json")) {
                result.put(key.substring(0, key.length() - 5), Jsons.loads(str(result.get(key)), null));
            }
        }
        if (result.containsKey("object_name") && str(result.get("object_name")).isBlank()) {
            result.put("object_name", UNCATEGORIZED_OBJECT);
        }
        if (result.containsKey("cmd_name") && str(result.get("cmd_name")).isBlank()) {
            result.put("cmd_name", UNKNOWN_COMMAND);
        }
        if (result.containsKey("match_mode") && str(result.get("match_mode")).isBlank()) {
            result.put("match_mode", "command_only");
        }
        if (result.containsKey("slot_key") && str(result.get("slot_key")).isBlank() && result.get("slot_id") != null) {
            result.put("slot_key", normalizedSlotKey(normalizeSlotId(result.get("slot_id")), null));
        }
        if (result.containsKey("match_mode")) {
            String type = isCommandBreakpoint(str(result.get("match_mode"))) ? "command" : "condition";
            result.put("breakpointType", type);
            result.put("breakpoint_type", type);
            result.put("breakpointTypeLabel", "command".equals(type) ? "命令断点" : "条件断点");
            result.put("breakpoint_type_label", result.get("breakpointTypeLabel"));
        }
        addCamelAliases(result);
        if (result.containsKey("breakpoint_id")) {
            result.put("hitBreakpoint", !str(result.get("breakpoint_id")).isBlank());
        }
        return result;
    }

    private void addCamelAliases(Map<String, Object> row) {
        Map<String, String> aliases = new HashMap<>();
        aliases.put("call_id", "callId");
        aliases.put("call_index", "callIndex");
        aliases.put("session_id", "sessionId");
        aliases.put("object_name", "objectName");
        aliases.put("cmd_name", "cmdName");
        aliases.put("slot_id", "slotId");
        aliases.put("breakpoint_id", "breakpointId");
        aliases.put("cost_ms", "durationMs");
        aliases.put("created_at", "createdAt");
        aliases.put("started_at", "startedAt");
        aliases.put("finished_at", "finishedAt");
        aliases.put("params_summary", "paramsSummary");
        aliases.put("result_summary", "resultSummary");
        aliases.put("params_preview", "paramsPreview");
        aliases.put("result_preview", "resultPreview");
        aliases.put("params_size", "paramsSize");
        aliases.put("result_size", "resultSize");
        aliases.put("params_hash", "paramsHash");
        aliases.put("result_hash", "resultHash");
        aliases.put("params_truncated", "paramsTruncated");
        aliases.put("result_truncated", "resultTruncated");
        aliases.put("params_payload_id", "paramsPayloadId");
        aliases.put("result_payload_id", "resultPayloadId");
        aliases.put("payload_status", "payloadStatus");
        aliases.put("params_fingerprint", "paramsFingerprint");
        aliases.put("params_sample_count", "paramsSampleCount");
        aliases.put("seen_count", "sampleCount");
        aliases.put("first_seen_at", "firstSeenAt");
        aliases.put("last_seen_at", "lastSeenAt");
        aliases.put("source_call_id", "sourceCallId");
        aliases.forEach((source, target) -> {
            if (row.containsKey(source) && !row.containsKey(target)) {
                row.put(target, row.get(source));
            }
        });
    }

    private Query callListWhere(String sid, String objectName, String keyword, String status) {
        List<String> clauses = new ArrayList<>();
        List<Object> args = new ArrayList<>();
        clauses.add("c.session_id=?");
        args.add(sid);
        if (objectName != null && !objectName.isBlank()) {
            clauses.add("c.object_name=?");
            args.add(objectName);
        }
        if (status != null && !status.isBlank()) {
            clauses.add("c.status=?");
            args.add(status);
        }
        if (keyword != null && !keyword.isBlank()) {
            String like = "%" + keyword.trim() + "%";
            clauses.add("""
                    (c.object_name LIKE ? OR c.cmd_name LIKE ? OR c.description LIKE ?
                     OR c.params_summary LIKE ? OR c.result_summary LIKE ?
                     OR c.exception_message LIKE ? OR c.call_id LIKE ?)
                    """);
            for (int index = 0; index < 7; index++) {
                args.add(like);
            }
        }
        return new Query("WHERE " + String.join(" AND ", clauses), args);
    }

    private Query interfaceListWhere(String sid, String objectName, String keyword, String status) {
        List<String> clauses = new ArrayList<>();
        List<Object> args = new ArrayList<>();
        clauses.add("session_id=?");
        args.add(sid);
        if (objectName != null && !objectName.isBlank()) {
            clauses.add("object_name=?");
            args.add(objectName);
        }
        if ("exception".equals(status)) {
            clauses.add("COALESCE(exception_count, 0) > 0");
        } else if ("success".equals(status)) {
            clauses.add("COALESCE(success_count, 0) > 0");
        }
        if (keyword != null && !keyword.isBlank()) {
            String like = "%" + keyword.trim() + "%";
            clauses.add("""
                    (object_name LIKE ? OR cmd_name LIKE ? OR display_name LIKE ?
                     OR description LIKE ? OR params_summary LIKE ? OR interface_alias LIKE ?)
                    """);
            for (int index = 0; index < 6; index++) {
                args.add(like);
            }
        }
        return new Query("WHERE " + String.join(" AND ", clauses), args);
    }

    private String callListOrder(String sortBy, String sortOrder) {
        Map<String, String> columns = Map.of(
                "call_index", "c.call_index",
                "created_at", "c.created_at",
                "updated_at", "c.updated_at",
                "cost_ms", "c.cost_ms",
                "cmd_name", "c.cmd_name",
                "object_name", "c.object_name",
                "slot_id", "c.slot_id",
                "status", "c.status",
                "hit", "CASE WHEN c.breakpoint_id IS NOT NULL AND c.breakpoint_id<>'' THEN 1 ELSE 0 END");
        String column = columns.getOrDefault(TextUtil.snakeCase(sortBy), "c.id");
        String direction = "asc".equalsIgnoreCase(sortOrder) ? "ASC" : "DESC";
        return "ORDER BY " + column + " " + direction + ", c.id DESC";
    }

    private String interfaceListOrder(String sortBy, String sortOrder) {
        Map<String, String> columns = Map.of(
                "last_seen_at", "last_seen_at",
                "first_seen_at", "first_seen_at",
                "call_count", "call_count",
                "success_count", "success_count",
                "exception_count", "exception_count",
                "avg_cost_ms", "avg_cost_ms",
                "cmd_name", "cmd_name",
                "object_name", "object_name");
        String key = TextUtil.snakeCase(sortBy == null || sortBy.isBlank() ? "last_seen_at" : sortBy);
        String column = columns.getOrDefault(key, "last_seen_at");
        String direction = "asc".equalsIgnoreCase(sortOrder) ? "ASC" : "DESC";
        return "ORDER BY " + column + " " + direction + ", id DESC";
    }

    private Map<String, Object> findDuplicateBreakpoint(Map<String, Object> data) {
        String matchMode = strOr(data.get("matchMode"), "command_only");
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT * FROM breakpoint
                WHERE session_id=? AND object_name=? AND cmd_name=? AND COALESCE(match_mode, 'command_only')=?
                """, data.get("sessionId"), data.get("objectName"), data.get("cmdName"), matchMode);
        for (Map<String, Object> row : rows) {
            Map<String, Object> item = normalize(row);
            if (isCommandBreakpoint(matchMode)) {
                return item;
            }
            String slotKey = normalizedSlotKey(normalizeSlotId(data.get("slotId")), str(data.get("slotKey")));
            if (!str(item.get("slot_key")).equals(str(slotKey))) {
                continue;
            }
            if ("params_snapshot".equals(matchMode)
                    && str(item.get("params_fingerprint")).equals(str(data.get("paramsFingerprint")))) {
                return item;
            }
            if ("params_condition".equals(matchMode)
                    && Jsons.dumps(item.get("conditions")).equals(Jsons.dumps(data.get("conditions")))) {
                return item;
            }
        }
        return null;
    }

    private boolean isCommandBreakpoint(String matchMode) {
        return matchMode == null || matchMode.isBlank() || "command_only".equals(matchMode);
    }

    private boolean isConditionBreakpoint(String matchMode) {
        return !isCommandBreakpoint(matchMode);
    }

    private String stateName(int pausedCount) {
        if (sessionId == null) {
            return "NO_SESSION";
        }
        if (!debugging) {
            return "SESSION_IDLE";
        }
        if (pausedCount > 0) {
            return "DEBUGGING_PAUSED";
        }
        return "DEBUGGING";
    }

    private int breakpointCount(String sid) {
        if (sid == null) {
            return 0;
        }
        return count("SELECT COUNT(*) FROM breakpoint WHERE session_id=?", sid);
    }

    private void saveCurrentSessionState(String sid) {
        String now = TextUtil.nowIso();
        jdbc.update("""
                INSERT INTO app_setting (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at
                """, CURRENT_SESSION_ID_SETTING, sid == null ? "" : sid, now);
        jdbc.update("""
                INSERT INTO app_setting (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at
                """, CURRENT_SESSION_OPEN_SETTING, sid == null ? "0" : "1", now);
    }

    private String nextUntitledSessionName() {
        int index = 1;
        while (exists("SELECT id FROM debug_session WHERE display_name=?", "未命名 " + index)) {
            index++;
        }
        return "未命名 " + index;
    }

    private Integer normalizeSlotId(Object value) {
        if (value == null || str(value).isBlank()) {
            return null;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        try {
            return Integer.parseInt(str(value));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String normalizedSlotKey(Integer slotId, String rawSlotKey) {
        if (rawSlotKey != null && !rawSlotKey.isBlank()) {
            return rawSlotKey;
        }
        return slotKey(slotId);
    }

    private String slotKey(Integer slotId) {
        return slotId == null ? NULL_SLOT_KEY : String.valueOf(slotId);
    }

    private String settingValue(String key) {
        Map<String, Object> row = first("SELECT value FROM app_setting WHERE key=?", key);
        return row == null ? null : str(row.get("value"));
    }

    private Map<String, Object> first(String sql, Object... args) {
        List<Map<String, Object>> rows = jdbc.queryForList(sql, args);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private Object scalar(String sql, Object... args) {
        return jdbc.queryForObject(sql, Object.class, args);
    }

    private int count(String sql, Object... args) {
        Number value = jdbc.queryForObject(sql, Number.class, args);
        return value == null ? 0 : value.intValue();
    }

    private boolean exists(String sql, Object... args) {
        return first(sql, args) != null;
    }

    private int pageValue(Object value) {
        return Math.max(1, intValue(value, 1));
    }

    private int pageSizeValue(Object value) {
        int size = intValue(value, DEFAULT_PAGE_SIZE);
        return Math.min(Math.max(1, size), MAX_PAGE_SIZE);
    }

    private int intValue(Object value, int defaultValue) {
        if (value instanceof Number number) {
            return number.intValue();
        }
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (Exception e) {
            return defaultValue;
        }
    }

    private String firstNonEmpty(Object... values) {
        for (Object value : values) {
            String text = nonEmpty(value);
            if (text != null) {
                return text;
            }
        }
        return null;
    }

    private String nonEmpty(Object value) {
        String text = str(value);
        return text.isBlank() ? null : text;
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private String strOr(Object value, String fallback) {
        String text = str(value);
        return text.isBlank() ? fallback : text;
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }

    private boolean bool(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        if (value instanceof Number number) {
            return number.intValue() != 0;
        }
        String text = str(value);
        return "1".equals(text) || "true".equalsIgnoreCase(text) || "yes".equalsIgnoreCase(text);
    }

    public static Map<String, Object> mapOf(Object... values) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (int index = 0; index < values.length; index += 2) {
            result.put(String.valueOf(values[index]), values[index + 1]);
        }
        return result;
    }

    private record InterfaceResolution(String interfaceId, int interfaceRegistered, int discoveryEnabled) {
    }

    private record Query(String sql, List<Object> args) {
    }
}
