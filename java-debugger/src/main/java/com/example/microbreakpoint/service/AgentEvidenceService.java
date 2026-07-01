package com.example.microbreakpoint.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.util.TextUtil;

@Service
public class AgentEvidenceService {

    private final JdbcTemplate jdbc;

    public AgentEvidenceService(DebugService debugService) {
        this.jdbc = debugService.jdbc();
    }

    public Map<String, Object> build(Map<String, Object> payload) {
        List<String> ids = interactionIds(payload.get("interaction_ids"));
        String focus = str(payload.get("focus"));
        if (ids.isEmpty()) {
            return Map.of("ok", false, "status", "invalid_request", "message", "interaction_ids 不能为空。",
                    "entities", List.of());
        }
        List<Map<String, Object>> interactions = new ArrayList<>();
        for (String id : ids) {
            Map<String, Object> row = interactionRow(id);
            if (row == null) {
                return Map.of("ok", false, "status", "not_found", "message", "交互记录不存在：" + id,
                        "entities", List.of());
            }
            interactions.add(interaction(row));
        }
        List<Map<String, Object>> differences = differences(interactions);
        List<Map<String, Object>> payloadRefs = payloadRefs(interactions);
        List<Map<String, Object>> findings = findings(interactions, differences);
        String bundleId = "evb-" + TextUtil.sha256(focus + "|" + String.join("|", ids)).substring(0, 16);
        List<Map<String, Object>> entities = new ArrayList<>();
        entities.add(entity("evidence_bundle", bundleId, focus.isBlank() ? "Evidence bundle" : focus, "available"));
        for (Map<String, Object> interaction : interactions) {
            entities.add(entity("interaction", interaction.get("interaction_id"), interaction.get("label"),
                    interaction.get("status")));
        }
        for (Map<String, Object> ref : payloadRefs) {
            entities.add(entity("payload", ref.get("payload_ref"), ref.get("label"), "available"));
        }
        return Map.of(
                "ok", true,
                "status", "available",
                "evidence_bundle_id", bundleId,
                "focus", focus,
                "interactions", interactions,
                "differences", differences,
                "payload_refs", payloadRefs,
                "findings", findings,
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
        item.put("exception_summary", exceptionSummary(row));
        item.put("cost_ms", row.get("cost_ms"));
        item.put("started_at", row.get("created_at"));
        item.put("finished_at", row.get("finished_at"));
        item.put("updated_at", row.get("updated_at"));
        return item;
    }

    private List<Map<String, Object>> differences(List<Map<String, Object>> interactions) {
        if (interactions.size() < 2) {
            return List.of();
        }
        Map<String, Object> left = interactions.get(0);
        List<Map<String, Object>> result = new ArrayList<>();
        for (int index = 1; index < interactions.size(); index++) {
            Map<String, Object> right = interactions.get(index);
            for (String field : List.of("status", "breakpoint_rule_id", "request_summary", "response_summary",
                    "exception_summary", "cost_ms", "request_payload_ref", "response_payload_ref")) {
                if (!str(left.get(field)).equals(str(right.get(field)))) {
                    Map<String, Object> diff = new LinkedHashMap<>();
                    diff.put("left_interaction_id", left.get("interaction_id"));
                    diff.put("right_interaction_id", right.get("interaction_id"));
                    diff.put("field_path", field);
                    diff.put("left", left.get(field));
                    diff.put("right", right.get(field));
                    result.add(diff);
                }
            }
        }
        return result;
    }

    private List<Map<String, Object>> payloadRefs(List<Map<String, Object>> interactions) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> interaction : interactions) {
            addPayloadRef(result, interaction, "request_payload_ref", "request");
            addPayloadRef(result, interaction, "response_payload_ref", "response");
        }
        return result;
    }

    private void addPayloadRef(List<Map<String, Object>> result, Map<String, Object> interaction, String key,
            String payloadType) {
        Object ref = interaction.get(key);
        if (str(ref).isBlank()) {
            return;
        }
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("payload_ref", ref);
        item.put("interaction_id", interaction.get("interaction_id"));
        item.put("payload_type", payloadType);
        item.put("label", interaction.get("label") + " " + payloadType);
        result.add(item);
    }

    private List<Map<String, Object>> findings(List<Map<String, Object>> interactions,
            List<Map<String, Object>> differences) {
        List<Map<String, Object>> result = new ArrayList<>();
        result.add(finding("fact", "交互数量", "证据包包含 " + interactions.size() + " 次交互。"));
        for (Map<String, Object> interaction : interactions) {
            if (!exceptionSummaryEmpty(interaction.get("exception_summary"))) {
                result.add(finding("fact", "异常交互",
                        interaction.get("interaction_id") + " 存在异常：" + interaction.get("exception_summary")));
            }
        }
        if (!differences.isEmpty()) {
            result.add(finding("fact", "交互差异", "已发现 " + differences.size() + " 个轻量字段差异。"));
        }
        return result;
    }

    private Map<String, Object> finding(String kind, String title, String message) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("kind", kind);
        item.put("title", title);
        item.put("message", message);
        return item;
    }

    private Map<String, Object> exceptionSummary(Map<String, Object> row) {
        String type = str(row.get("exception_type"));
        String message = str(row.get("exception_message"));
        return type.isBlank() && message.isBlank() ? Map.of() : Map.of("type", type, "message", message);
    }

    private boolean exceptionSummaryEmpty(Object value) {
        return value instanceof Map<?, ?> map && map.isEmpty();
    }

    private Map<String, Object> entity(String type, Object id, Object label, Object status) {
        Map<String, Object> entity = new LinkedHashMap<>();
        entity.put("type", type);
        entity.put("id", id);
        entity.put("label", label);
        entity.put("status", status);
        return entity;
    }

    private List<String> interactionIds(Object value) {
        if (!(value instanceof List<?> items)) {
            return List.of();
        }
        return items.stream().map(this::str).filter(item -> !item.isBlank()).toList();
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }
}
