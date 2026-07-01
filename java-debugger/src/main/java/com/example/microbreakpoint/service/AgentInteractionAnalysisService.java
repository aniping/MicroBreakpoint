package com.example.microbreakpoint.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.util.Jsons;

@Service
public class AgentInteractionAnalysisService {

    private final DebugService debugService;
    private final JdbcTemplate jdbc;

    public AgentInteractionAnalysisService(DebugService debugService) {
        this.debugService = debugService;
        this.jdbc = debugService.jdbc();
    }

    public Map<String, Object> analyze(Map<String, Object> payload) {
        String sessionId = sessionId(payload);
        if (sessionId.isBlank()) {
            return Map.of("ok", true, "interactions", List.of(), "summary", Map.of("returned_count", 0),
                    "entities", List.of(), "message", "请先新建或选择会话。");
        }
        Map<String, Object> target = object(payload.get("target"));
        Map<String, Object> filters = object(payload.get("filters"));
        String objectName = str(firstNonNull(target.get("object"), target.get("objectName")));
        String cmdName = str(firstNonNull(target.get("command"), target.get("cmdName")));
        String status = str(firstNonNull(filters.get("status"), payload.get("status")));
        boolean exceptionOnly = bool(firstNonNull(filters.get("exception_only"), filters.get("exceptionOnly"),
                payload.get("exception_only"), payload.get("exceptionOnly")));
        String since = str(firstNonNull(filters.get("since"), filters.get("from"), payload.get("since"),
                payload.get("from")));
        String until = str(firstNonNull(filters.get("until"), filters.get("to"), payload.get("until"),
                payload.get("to")));
        int limit = Math.max(1, Math.min(50, intValue(firstNonNull(filters.get("limit"), payload.get("limit")), 20)));

        StringBuilder sql = new StringBuilder("""
                SELECT call_id, object_name, cmd_name, status, breakpoint_id, breakpoint_name,
                       params_summary, result_summary, params_payload_id, result_payload_id,
                       exception_type, exception_message, cost_ms, created_at, finished_at, updated_at
                FROM call_record
                WHERE session_id=?
                """);
        List<Object> args = new ArrayList<>();
        args.add(sessionId);
        if (!objectName.isBlank()) {
            sql.append(" AND object_name=?");
            args.add(objectName);
        }
        if (!cmdName.isBlank()) {
            sql.append(" AND cmd_name=?");
            args.add(cmdName);
        }
        if (!status.isBlank()) {
            sql.append(" AND status=?");
            args.add(status);
        }
        if (exceptionOnly) {
            sql.append(" AND (status='exception' OR exception_type IS NOT NULL OR exception_message IS NOT NULL)");
        }
        if (!since.isBlank()) {
            sql.append(" AND created_at>=?");
            args.add(since);
        }
        if (!until.isBlank()) {
            sql.append(" AND created_at<=?");
            args.add(until);
        }
        sql.append(" ORDER BY updated_at DESC, id DESC LIMIT ?");
        args.add(limit);

        List<Map<String, Object>> interactions = new ArrayList<>();
        List<Map<String, Object>> entities = new ArrayList<>();
        Map<String, Integer> statusCounts = new LinkedHashMap<>();
        for (Map<String, Object> row : jdbc.queryForList(sql.toString(), args.toArray())) {
            Map<String, Object> interaction = interaction(row);
            interactions.add(interaction);
            statusCounts.merge(str(row.get("status")), 1, Integer::sum);
            entities.add(entity("interaction", interaction.get("interaction_id"), interaction.get("label"),
                    interaction.get("status")));
            addPayloadEntity(entities, interaction.get("request_payload_ref"), interaction.get("label") + " request");
            addPayloadEntity(entities, interaction.get("response_payload_ref"), interaction.get("label") + " response");
        }

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("returned_count", interactions.size());
        summary.put("status_counts", statusCounts);
        summary.put("filters", Map.of(
                "exception_only", exceptionOnly,
                "since", since,
                "until", until));
        return Map.of("ok", true, "interactions", interactions, "summary", summary, "entities", entities);
    }

    public Map<String, Object> compare(Map<String, Object> payload) {
        List<String> ids = interactionIds(payload.get("interaction_ids"));
        if (ids.size() < 2) {
            return Map.of("ok", false, "status", "invalid_request", "message", "至少需要两个 interaction_id。",
                    "entities", List.of());
        }
        Map<String, Object> leftRow = interactionRow(ids.get(0));
        Map<String, Object> rightRow = interactionRow(ids.get(1));
        if (leftRow == null || rightRow == null) {
            return Map.of("ok", false, "status", "not_found", "message", "交互记录不存在。", "entities", List.of());
        }
        Map<String, Object> left = interaction(leftRow);
        Map<String, Object> right = interaction(rightRow);
        List<Map<String, Object>> differences = differences(left, right);
        List<Map<String, Object>> entities = new ArrayList<>();
        entities.add(entity("interaction", left.get("interaction_id"), left.get("label"), left.get("status")));
        entities.add(entity("interaction", right.get("interaction_id"), right.get("label"), right.get("status")));
        for (Map<String, Object> item : List.of(left, right)) {
            addPayloadEntity(entities, item.get("request_payload_ref"), item.get("label") + " request");
            addPayloadEntity(entities, item.get("response_payload_ref"), item.get("label") + " response");
        }
        return Map.of(
                "ok", true,
                "base_interaction_id", left.get("interaction_id"),
                "compared_interaction_id", right.get("interaction_id"),
                "interactions", List.of(left, right),
                "differences", differences,
                "entities", entities);
    }

    private Map<String, Object> interactionRow(String interactionId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                SELECT call_id, object_name, cmd_name, status, breakpoint_id, breakpoint_name,
                       params_summary, result_summary, params_payload_id, result_payload_id,
                       exception_type, exception_message, cost_ms, created_at, finished_at, updated_at
                FROM call_record
                WHERE call_id=?
                """, interactionId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private Map<String, Object> interaction(Map<String, Object> row) {
        String objectName = str(row.get("object_name"));
        String cmdName = str(row.get("cmd_name"));
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("interaction_id", row.get("call_id"));
        item.put("label", objectName + "." + cmdName);
        item.put("status", row.get("status"));
        item.put("breakpoint_rule_id", row.get("breakpoint_id"));
        item.put("request_payload_ref", row.get("params_payload_id"));
        item.put("response_payload_ref", row.get("result_payload_id"));
        item.put("request_summary", row.get("params_summary"));
        item.put("response_summary", row.get("result_summary"));
        item.put("field_index", fieldIndex(row));
        item.put("exception_summary", exceptionSummary(row));
        item.put("cost_ms", row.get("cost_ms"));
        item.put("started_at", row.get("created_at"));
        item.put("finished_at", row.get("finished_at"));
        item.put("updated_at", row.get("updated_at"));
        return item;
    }

    private List<Map<String, Object>> fieldIndex(Map<String, Object> row) {
        List<Map<String, Object>> result = new ArrayList<>();
        result.addAll(summaryFields(row.get("params_summary"), "request.parameters", row.get("params_payload_id")));
        result.addAll(summaryFields(row.get("result_summary"), "response.result", row.get("result_payload_id")));
        return result;
    }

    private List<Map<String, Object>> summaryFields(Object summary, String pathPrefix, Object payloadRef) {
        if (str(payloadRef).isBlank()) {
            return List.of();
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (String part : str(summary).split(", ")) {
            int separator = part.indexOf('=');
            if (separator < 0) {
                continue;
            }
            String key = part.substring(0, separator).trim();
            if (key.isBlank() || "...".equals(key)) {
                continue;
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("field_path", pathPrefix + "." + key);
            item.put("payload_ref", payloadRef);
            item.put("value_summary", part.substring(separator + 1).trim());
            result.add(item);
        }
        return result;
    }

    private List<Map<String, Object>> differences(Map<String, Object> left, Map<String, Object> right) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (String field : List.of("status", "breakpoint_rule_id", "request_summary", "response_summary",
                "exception_summary", "cost_ms", "request_payload_ref", "response_payload_ref")) {
            if (!str(left.get(field)).equals(str(right.get(field)))) {
                Map<String, Object> diff = new LinkedHashMap<>();
                diff.put("field_path", field);
                diff.put("left", left.get(field));
                diff.put("right", right.get(field));
                result.add(diff);
            }
        }
        return result;
    }

    private List<String> interactionIds(Object value) {
        if (!(value instanceof List<?> items)) {
            return List.of();
        }
        return items.stream().map(this::str).filter(item -> !item.isBlank()).toList();
    }

    private Map<String, Object> exceptionSummary(Map<String, Object> row) {
        String type = str(row.get("exception_type"));
        String message = str(row.get("exception_message"));
        return type.isBlank() && message.isBlank() ? Map.of() : Map.of("type", type, "message", message);
    }

    private void addPayloadEntity(List<Map<String, Object>> entities, Object payloadRef, String label) {
        if (!str(payloadRef).isBlank()) {
            entities.add(entity("payload", payloadRef, label, "available"));
        }
    }

    private Map<String, Object> entity(String type, Object id, Object label, Object status) {
        Map<String, Object> entity = new LinkedHashMap<>();
        entity.put("type", type);
        entity.put("id", id);
        entity.put("label", label);
        entity.put("status", status);
        return entity;
    }

    private String sessionId(Map<String, Object> payload) {
        Object explicit = firstNonNull(payload.get("sessionId"), payload.get("session_id"));
        if (explicit != null) {
            return str(explicit);
        }
        Map<String, Object> state = debugService.stateResponse();
        return str(firstNonNull(state.get("sessionId"), state.get("currentSessionId")));
    }

    private Map<String, Object> object(Object value) {
        return Jsons.object(value);
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private int intValue(Object value, int defaultValue) {
        if (value instanceof Number number) {
            return number.intValue();
        }
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (RuntimeException e) {
            return defaultValue;
        }
    }

    private boolean bool(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        if (value instanceof Number number) {
            return number.intValue() != 0;
        }
        String text = str(value).trim().toLowerCase();
        return "1".equals(text) || "true".equals(text) || "yes".equals(text) || "on".equals(text);
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }
}
