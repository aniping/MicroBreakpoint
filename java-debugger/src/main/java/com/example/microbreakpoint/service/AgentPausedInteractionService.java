package com.example.microbreakpoint.service;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

@Service
public class AgentPausedInteractionService {

    private static final int DEFAULT_TIMEOUT_MS = 30_000;
    private static final int POLL_INTERVAL_MS = 100;

    private final DebugService debugService;

    public AgentPausedInteractionService(DebugService debugService) {
        this.debugService = debugService;
    }

    public Map<String, Object> list(Map<String, Object> payload) {
        return debugService.listPausedInteractions(payload);
    }

    public Map<String, Object> continueInteraction(String interactionId) {
        return debugService.continuePausedInteraction(interactionId);
    }

    public Map<String, Object> waitPaused(Map<String, Object> payload) {
        long timeoutMs = Math.max(0, longValue(firstNonNull(payload.get("timeout_ms"), payload.get("timeoutMs")),
                DEFAULT_TIMEOUT_MS));
        long deadline = System.currentTimeMillis() + timeoutMs;
        while (true) {
            Map<String, Object> listed = list(payload);
            List<Map<String, Object>> interactions = interactions(listed);
            if (!interactions.isEmpty()) {
                Map<String, Object> item = interactions.get(0);
                return Map.of(
                        "ok", true,
                        "status", "paused",
                        "breakpoint_rule_id", str(firstNonNull(item.get("breakpoint_rule_id"),
                                payload.get("breakpoint_rule_id"))),
                        "interaction_id", str(item.get("interaction_id")),
                        "message", "目标调用已命中断点并暂停。",
                        "entities", listed.getOrDefault("entities", List.of()));
            }
            long remaining = deadline - System.currentTimeMillis();
            if (remaining <= 0) {
                return Map.of(
                        "ok", false,
                        "status", "timeout",
                        "breakpoint_rule_id", firstNonNull(payload.get("breakpoint_rule_id"), ""),
                        "message", "等待超时，目标调用尚未命中断点。",
                        "entities", List.of());
            }
            try {
                Thread.sleep(Math.min(POLL_INTERVAL_MS, remaining));
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return Map.of(
                        "ok", false,
                        "status", "timeout",
                        "breakpoint_rule_id", firstNonNull(payload.get("breakpoint_rule_id"), ""),
                        "message", "等待被中断，目标调用尚未命中断点。",
                        "entities", List.of());
            }
        }
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> interactions(Map<String, Object> result) {
        Object value = result.get("interactions");
        return value instanceof List<?> list ? (List<Map<String, Object>>) list : List.of();
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
}
