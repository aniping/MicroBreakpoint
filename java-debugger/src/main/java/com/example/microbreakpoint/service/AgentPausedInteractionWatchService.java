package com.example.microbreakpoint.service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Service;

import com.example.microbreakpoint.util.Jsons;
import com.example.microbreakpoint.util.TextUtil;

@Service
public class AgentPausedInteractionWatchService {

    private static final long DEFAULT_EXPIRES_IN_MS = 300_000;
    private static final int MAX_EVENTS = 200;

    private final Map<String, Watch> watches = new LinkedHashMap<>();
    private final List<Map<String, Object>> events = new ArrayList<>();
    private final AtomicLong eventSequence = new AtomicLong();

    public synchronized Map<String, Object> watch(Map<String, Object> payload) {
        cleanupExpired();
        String ruleId = str(payload.get("breakpoint_rule_id"));
        Map<String, Object> target = Jsons.object(payload.get("target"));
        String objectName = str(firstNonNull(target.get("object"), target.get("objectName")));
        String cmdName = str(firstNonNull(target.get("command"), target.get("cmdName")));
        if (ruleId.isBlank() && objectName.isBlank() && cmdName.isBlank()) {
            return error("invalid_request", "", "breakpoint_rule_id 或 target 不能为空。");
        }
        String watchId = "watch-" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String label = label(objectName, cmdName, ruleId);
        long expiresAt = System.currentTimeMillis()
                + Math.max(1, longValue(firstNonNull(payload.get("expires_in_ms"), payload.get("expiresInMs")),
                        DEFAULT_EXPIRES_IN_MS));
        watches.put(watchId, new Watch(watchId, ruleId, objectName, cmdName, label, expiresAt));
        return Map.of(
                "ok", true,
                "status", "watching",
                "watch_id", watchId,
                "message", "已开始等待 " + label + " 命中断点；命中后会提醒。",
                "entities", List.of(entity("paused_interaction_watch", watchId, label, "watching")));
    }

    public synchronized Map<String, Object> cancel(String watchId) {
        Watch watch = watches.remove(watchId);
        if (watch == null) {
            return error("not_found", watchId, "暂停提醒不存在。");
        }
        return Map.of(
                "ok", true,
                "status", "cancelled",
                "watch_id", watchId,
                "message", "暂停提醒已取消；断点规则不受影响。",
                "entities", List.of(entity("paused_interaction_watch", watchId, watch.label, "cancelled")));
    }

    public synchronized Map<String, Object> listEvents(String watchId, String afterEventId) {
        cleanupExpired();
        long afterSequence = eventSequence(afterEventId);
        List<Map<String, Object>> result = events.stream()
                .filter(event -> watchId == null || watchId.isBlank() || watchId.equals(event.get("watch_id")))
                .filter(event -> ((Number) event.get("sequence")).longValue() > afterSequence)
                .toList();
        return Map.of("ok", true, "events", result, "entities", eventEntities(result));
    }

    public synchronized void recordPaused(String breakpointRuleId, String objectName, String cmdName,
            String interactionId) {
        cleanupExpired();
        for (Watch watch : new ArrayList<>(watches.values())) {
            if (!watch.matches(breakpointRuleId, objectName, cmdName)) {
                continue;
            }
            Map<String, Object> event = event(watch, breakpointRuleId, objectName, cmdName, interactionId);
            events.add(event);
            watches.remove(watch.watchId);
        }
        trimEvents();
    }

    private Map<String, Object> event(Watch watch, String breakpointRuleId, String objectName, String cmdName,
            String interactionId) {
        long sequence = eventSequence.incrementAndGet();
        String label = label(objectName, cmdName, breakpointRuleId);
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("sequence", sequence);
        event.put("event_id", "evt-" + sequence);
        event.put("event", "interaction_paused");
        event.put("watch_id", watch.watchId);
        event.put("breakpoint_rule_id", breakpointRuleId);
        event.put("interaction_id", interactionId);
        event.put("created_at", TextUtil.nowIso());
        event.put("entities", List.of(
                entity("paused_interaction_watch", watch.watchId, watch.label, "triggered"),
                entity("interaction", interactionId, label, "paused")));
        return event;
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> eventEntities(List<Map<String, Object>> sourceEvents) {
        List<Map<String, Object>> result = new ArrayList<>();
        List<String> seen = new ArrayList<>();
        for (Map<String, Object> event : sourceEvents) {
            Object rawEntities = event.get("entities");
            if (!(rawEntities instanceof List<?> entities)) {
                continue;
            }
            for (Object rawEntity : entities) {
                if (!(rawEntity instanceof Map<?, ?>)) {
                    continue;
                }
                Map<String, Object> entity = (Map<String, Object>) rawEntity;
                String key = str(entity.get("type")) + "|" + str(entity.get("id"));
                if (seen.contains(key)) {
                    continue;
                }
                seen.add(key);
                result.add(entity);
            }
        }
        return result;
    }

    private void cleanupExpired() {
        long now = System.currentTimeMillis();
        watches.entrySet().removeIf(entry -> entry.getValue().expiresAt < now);
    }

    private void trimEvents() {
        if (events.size() > MAX_EVENTS) {
            events.subList(0, events.size() - MAX_EVENTS).clear();
        }
    }

    private long eventSequence(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            return 0;
        }
        try {
            return Long.parseLong(eventId.replace("evt-", ""));
        } catch (RuntimeException e) {
            return 0;
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

    private Map<String, Object> error(String status, String watchId, String message) {
        return Map.of("ok", false, "status", status, "watch_id", watchId, "message", message, "entities", List.of());
    }

    private String label(String objectName, String cmdName, String fallback) {
        if (!objectName.isBlank() || !cmdName.isBlank()) {
            return objectName + "." + cmdName;
        }
        return fallback;
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private long longValue(Object value, long defaultValue) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        try {
            return Long.parseLong(String.valueOf(value));
        } catch (RuntimeException e) {
            return defaultValue;
        }
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }

    private static class Watch {
        private final String watchId;
        private final String breakpointRuleId;
        private final String objectName;
        private final String cmdName;
        private final String label;
        private final long expiresAt;

        Watch(String watchId, String breakpointRuleId, String objectName, String cmdName, String label,
                long expiresAt) {
            this.watchId = watchId;
            this.breakpointRuleId = breakpointRuleId;
            this.objectName = objectName;
            this.cmdName = cmdName;
            this.label = label;
            this.expiresAt = expiresAt;
        }

        boolean matches(String ruleId, String objectNameValue, String cmdNameValue) {
            if (!breakpointRuleId.isBlank() && breakpointRuleId.equals(ruleId)) {
                return true;
            }
            boolean objectMatches = objectName.isBlank() || objectName.equals(objectNameValue);
            boolean commandMatches = cmdName.isBlank() || cmdName.equals(cmdNameValue);
            return objectMatches && commandMatches;
        }
    }
}
