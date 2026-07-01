package com.example.microbreakpoint.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class AgentBreakpointService {

    private final DebugService debugService;
    private final JdbcTemplate jdbc;

    public AgentBreakpointService(DebugService debugService) {
        this.debugService = debugService;
        this.jdbc = debugService.jdbc();
    }

    public Map<String, Object> declare(Map<String, Object> payload) {
        return debugService.declareBreakpointRule(payload);
    }

    public Map<String, Object> list(String sessionId) {
        List<Map<String, Object>> rules = debugService.listBreakpoints(sessionId).stream()
                .map(this::agentRule)
                .toList();
        return Map.of(
                "ok", true,
                "breakpoint_rules", rules,
                "entities", rules.stream().map(this::entity).toList());
    }

    public Map<String, Object> get(String ruleId) {
        Map<String, Object> row = row(ruleId);
        if (row == null) {
            return error("not_found", ruleId, "断点规则不存在。");
        }
        Map<String, Object> rule = agentRule(row);
        return response(rule, "断点规则已读取。");
    }

    public Map<String, Object> setEnabled(String ruleId, boolean enabled) {
        if (row(ruleId) == null) {
            return error("not_found", ruleId, "断点规则不存在。");
        }
        debugService.setBreakpointEnabled(ruleId, enabled);
        Map<String, Object> rule = agentRule(row(ruleId));
        return response(rule, enabled ? "断点规则已启用。" : "断点规则已禁用。");
    }

    public Map<String, Object> delete(String ruleId) {
        Map<String, Object> row = row(ruleId);
        if (row == null) {
            return error("not_found", ruleId, "断点规则不存在。");
        }
        Map<String, Object> rule = agentRule(row);
        debugService.deleteBreakpoint(ruleId);
        rule.put("status", "cancelled");
        return response(rule, "断点规则已取消。");
    }

    private Map<String, Object> row(String ruleId) {
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT * FROM breakpoint WHERE id=?", ruleId);
        return rows.isEmpty() ? null : debugService.normalize(rows.get(0));
    }

    private Map<String, Object> agentRule(Map<String, Object> row) {
        String objectName = str(firstNonNull(row.get("objectName"), row.get("object_name")));
        String cmdName = str(firstNonNull(row.get("cmdName"), row.get("cmd_name")));
        String displayName = str(firstNonNull(row.get("displayName"), row.get("display_name")));
        String matchMode = str(firstNonNull(row.get("matchMode"), row.get("match_mode")));
        boolean enabled = bool(row.get("enabled"));
        Map<String, Object> target = new LinkedHashMap<>();
        target.put("object", objectName);
        target.put("command", cmdName);
        target.put("display_name", displayName);
        target.put("session_id", firstNonNull(row.get("sessionId"), row.get("session_id")));

        Map<String, Object> match = new LinkedHashMap<>();
        match.put("type", "params_condition".equals(matchMode) ? "parameters" : "interface");
        match.put("mode", matchMode);
        if ("params_condition".equals(matchMode)) {
            match.put("conditions", firstNonNull(row.get("conditions"), List.of()));
        }

        Map<String, Object> rule = new LinkedHashMap<>();
        rule.put("breakpoint_rule_id", row.get("id"));
        rule.put("label", label(objectName, cmdName, displayName));
        rule.put("status", enabled ? "armed" : "disabled");
        rule.put("target", target);
        rule.put("match", match);
        rule.put("hit_count", firstNonNull(row.get("hitCount"), row.get("hit_count"), 0));
        rule.put("source_type", firstNonNull(row.get("sourceType"), row.get("source_type")));
        rule.put("created_at", firstNonNull(row.get("createdAt"), row.get("created_at")));
        rule.put("updated_at", firstNonNull(row.get("updatedAt"), row.get("updated_at")));
        return rule;
    }

    private Map<String, Object> response(Map<String, Object> rule, String message) {
        Map<String, Object> result = new LinkedHashMap<>(rule);
        result.put("ok", true);
        result.put("message", message);
        result.put("entities", List.of(entity(rule)));
        return result;
    }

    private Map<String, Object> entity(Map<String, Object> rule) {
        Map<String, Object> entity = new LinkedHashMap<>();
        entity.put("type", "breakpoint_rule");
        entity.put("id", rule.get("breakpoint_rule_id"));
        entity.put("label", rule.get("label"));
        entity.put("status", rule.get("status"));
        return entity;
    }

    private Map<String, Object> error(String status, String ruleId, String message) {
        return Map.of(
                "ok", false,
                "status", status,
                "breakpoint_rule_id", ruleId,
                "message", message,
                "entities", List.of());
    }

    private String label(String objectName, String cmdName, String displayName) {
        return displayName.isBlank() ? objectName + "." + cmdName : displayName;
    }

    private boolean bool(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        if (value instanceof Number number) {
            return number.intValue() != 0;
        }
        return Boolean.parseBoolean(str(value)) || "1".equals(str(value));
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }
}
