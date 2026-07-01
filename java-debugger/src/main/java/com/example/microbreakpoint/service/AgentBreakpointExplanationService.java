package com.example.microbreakpoint.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.util.Jsons;

@Service
public class AgentBreakpointExplanationService {

    private final DebugService debugService;
    private final PayloadService payloadService;
    private final JdbcTemplate jdbc;

    public AgentBreakpointExplanationService(DebugService debugService, PayloadService payloadService) {
        this.debugService = debugService;
        this.payloadService = payloadService;
        this.jdbc = debugService.jdbc();
    }

    public Map<String, Object> explain(String ruleId, Map<String, Object> payload) {
        String interactionId = str(firstNonNull(payload.get("interaction_id"), payload.get("interactionId")));
        if (interactionId.isBlank()) {
            return error("invalid_request", ruleId, interactionId, "interaction_id 不能为空。");
        }
        Map<String, Object> rule = row("SELECT * FROM breakpoint WHERE id=?", ruleId);
        if (rule == null) {
            return error("not_found", ruleId, interactionId, "断点规则不存在。");
        }
        Map<String, Object> interaction = row("SELECT * FROM call_record WHERE call_id=?", interactionId);
        if (interaction == null) {
            return error("not_found", ruleId, interactionId, "交互记录不存在。");
        }
        rule = debugService.normalize(rule);
        interaction = debugService.normalize(interaction);

        boolean enabled = enabled(rule.get("enabled"));
        boolean targetMatched = str(rule.get("objectName")).equals(str(interaction.get("objectName")))
                && str(rule.get("cmdName")).equals(str(interaction.get("cmdName")));
        String matchMode = str(rule.get("matchMode"));
        List<Map<String, Object>> conditionResults = "params_condition".equals(matchMode)
                ? conditionResults(rule, interaction)
                : List.of();
        boolean conditionsMatched = conditionResults.stream()
                .allMatch(item -> Boolean.TRUE.equals(item.get("matched")));
        boolean matched = enabled && targetMatched && conditionsMatched;

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ok", true);
        result.put("breakpoint_rule_id", ruleId);
        result.put("interaction_id", interactionId);
        result.put("matched", matched);
        result.put("facts", Map.of(
                "rule_enabled", enabled,
                "target_matched", targetMatched,
                "conditions_matched", conditionsMatched,
                "match_mode", matchMode));
        result.put("condition_results", conditionResults);
        result.put("message", matched ? "该交互满足断点规则。" : "该交互不满足断点规则。");
        result.put("entities", List.of(
                entity("breakpoint_rule", ruleId, rule.get("objectName") + "." + rule.get("cmdName"),
                        enabled ? "armed" : "disabled"),
                entity("interaction", interactionId, interaction.get("objectName") + "." + interaction.get("cmdName"),
                        interaction.get("status"))));
        return result;
    }

    private List<Map<String, Object>> conditionResults(Map<String, Object> rule, Map<String, Object> interaction) {
        Object params = payloadValue(str(interaction.get("paramsPayloadId")));
        List<Map<String, Object>> results = new ArrayList<>();
        for (Object item : list(rule.get("conditions"))) {
            Map<String, Object> condition = Jsons.object(item);
            String path = str(condition.get("path"));
            String operator = str(firstNonNull(condition.get("operator"), condition.get("op"), "eq"));
            Object expected = condition.get("value");
            Object actual = fieldValue(params, path);
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("path", path);
            result.put("operator", operator);
            result.put("expected", expected);
            result.put("actual", actual);
            result.put("matched", compare(actual, operator, expected));
            results.add(result);
        }
        return results;
    }

    private Object payloadValue(String payloadId) {
        if (payloadId.isBlank()) {
            return Map.of();
        }
        Map<String, Object> row = payloadService.exportPayloadById(payloadId);
        if (row == null) {
            return Map.of();
        }
        return Jsons.loads(payloadService.readPayloadText(row), Map.of());
    }

    private Object fieldValue(Object root, String path) {
        Object current = root;
        for (String segment : fieldSegments(path)) {
            if (current instanceof Map<?, ?> map) {
                current = map.get(segment);
            } else if (current instanceof List<?> list) {
                try {
                    current = list.get(Integer.parseInt(segment));
                } catch (RuntimeException e) {
                    return null;
                }
            } else {
                return null;
            }
        }
        return current;
    }

    private List<String> fieldSegments(String path) {
        String normalized = path;
        for (String prefix : List.of("request.parameters.", "parameters.", "params.")) {
            if (normalized.startsWith(prefix)) {
                normalized = normalized.substring(prefix.length());
                break;
            }
        }
        return List.of(normalized.split("\\.")).stream().filter(item -> !item.isBlank()).toList();
    }

    private boolean compare(Object actual, String operator, Object expected) {
        return switch (operator) {
            case "ne" -> !equalsValue(actual, expected);
            case "gt" -> number(actual) > number(expected);
            case "gte" -> number(actual) >= number(expected);
            case "lt" -> number(actual) < number(expected);
            case "lte" -> number(actual) <= number(expected);
            case "contains" -> str(actual).contains(str(expected));
            default -> equalsValue(actual, expected);
        };
    }

    private boolean equalsValue(Object actual, Object expected) {
        return actual == null ? expected == null : str(actual).equals(str(expected));
    }

    private double number(Object value) {
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        try {
            return Double.parseDouble(str(value));
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    @SuppressWarnings("unchecked")
    private List<Object> list(Object value) {
        return value instanceof List<?> items ? (List<Object>) items : List.of();
    }

    private Map<String, Object> row(String sql, String id) {
        List<Map<String, Object>> rows = jdbc.queryForList(sql, id);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private Map<String, Object> entity(String type, Object id, Object label, Object status) {
        Map<String, Object> entity = new LinkedHashMap<>();
        entity.put("type", type);
        entity.put("id", id);
        entity.put("label", label);
        entity.put("status", status);
        return entity;
    }

    private Map<String, Object> error(String status, String ruleId, String interactionId, String message) {
        return Map.of("ok", false, "status", status, "breakpoint_rule_id", ruleId, "interaction_id", interactionId,
                "message", message, "entities", List.of());
    }

    private boolean enabled(Object value) {
        if (value instanceof Number number) {
            return number.intValue() != 0;
        }
        return Boolean.TRUE.equals(value) || "1".equals(str(value)) || "true".equalsIgnoreCase(str(value));
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
