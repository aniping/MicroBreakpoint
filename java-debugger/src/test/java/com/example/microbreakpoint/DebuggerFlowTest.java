package com.example.microbreakpoint;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import com.sun.net.httpserver.HttpServer;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "micro-breakpoint.database=target/test-data/debugger-flow.sqlite3",
        "micro-breakpoint.payload-root=target/test-data/payloads",
        "micro-breakpoint.breakpoint-timeout-seconds=1"
})
class DebuggerFlowTest {

    private static final AtomicBoolean DEMO_DEBUGGER_ENABLED = new AtomicBoolean(false);
    private static final HttpServer DEMO_SERVER = startDemoServer();
    private static final Path SETTINGS_FILE = Path.of("target/test-data/debugger-flow-settings.json");

    @Autowired
    private TestRestTemplate rest;

    @DynamicPropertySource
    static void demoProperties(DynamicPropertyRegistry registry) {
        registry.add("micro-breakpoint.settings-file", () -> SETTINGS_FILE.toString());
    }

    @AfterAll
    static void stopDemoServer() {
        DEMO_SERVER.stop(0);
    }

    @BeforeEach
    void reset() {
        writeSettings(DEMO_SERVER.getAddress().getPort(), 200);
        rest.postForObject("/api/debug/stop", Map.of(), Map.class);
        rest.exchange("/api/sessions", HttpMethod.DELETE, HttpEntity.EMPTY, Map.class);
        rest.postForObject("/api/interfaces/lock", Map.of("locked", false), Map.class);
        DEMO_DEBUGGER_ENABLED.set(false);
    }

    @Test
    void nonDebugReportsAreIgnored() {
        Map<String, Object> before = post("/api/calls/before", makeBefore("call-1", "SA", "start", 1, Map.of()));
        assertThat(before).containsEntry("action", "continue");

        Map<String, Object> after = post("/api/calls/after", Map.of(
                "callId", "call-1",
                "success", true,
                "costMs", 5,
                "result", Map.of("ok", true)));
        assertThat(after).containsEntry("ignored", true);
        assertThat(get("/api/debug/state")).containsEntry("state", "NO_SESSION");
        assertThat(items(get("/api/calls"))).isEmpty();
    }

    @Test
    void debugRecordsAndDiscoversByBusinessIdentity() {
        createAndStart();

        post("/api/calls/before", makeBefore("call-a", "SA", "start", 1, Map.of("mode", "A")));
        finish("call-a", true, 8);
        post("/api/calls/before", makeBefore("call-b", "SA", "start", 2, Map.of("mode", "B")));
        finish("call-b", true, 12);
        post("/api/calls/before", makeBefore("call-c", "SA", "stop", 1, Map.of("mode", "A")));
        finish("call-c", true, 4);

        List<Map<String, Object>> calls = items(get("/api/calls"));
        assertThat(calls).hasSize(3);
        assertThat(calls).allSatisfy(item -> assertThat(item).doesNotContainKeys("params", "result", "params_json"));

        List<Map<String, Object>> interfaces = items(get("/api/interfaces"));
        assertThat(interfaces).hasSize(2);
        Map<String, Map<String, Object>> byCommand = new LinkedHashMap<>();
        interfaces.forEach(item -> byCommand.put(String.valueOf(item.get("cmd_name")), item));
        assertThat(byCommand.get("start")).containsEntry("call_count", 2);
        assertThat(byCommand.get("start")).containsEntry("params_sample_count", 2);
        assertThat(byCommand.get("stop")).containsEntry("call_count", 1);
    }

    @Test
    void agentAnalyzeInteractionsFiltersExceptionAndTimeWindow() {
        createAndStart();

        post("/api/calls/before", makeBefore("analyze-ok", "VNA", "set", 1, Map.of("mode", "ok")));
        finish("analyze-ok", true, 5);
        post("/api/calls/before", makeBefore("analyze-error", "VNA", "set", 1, Map.of("mode", "bad")));
        finish("analyze-error", false, 30);

        Map<String, Object> exceptionOnly = post("/api/agent/interactions/analyze", Map.of(
                "target", Map.of("object", "VNA", "command", "set"),
                "filters", Map.of("exception_only", true)));
        assertThat(items(exceptionOnly, "interactions"))
                .extracting(item -> item.get("interaction_id"))
                .containsExactly("analyze-error");
        Map<String, Object> summary = (Map<String, Object>) exceptionOnly.get("summary");
        assertThat((Map<String, Object>) summary.get("status_counts")).containsEntry("exception", 1);
        assertThat((Map<String, Object>) summary.get("filters")).containsEntry("exception_only", true);

        Map<String, Object> futureWindow = post("/api/agent/interactions/analyze", Map.of(
                "target", Map.of("object", "VNA", "command", "set"),
                "filters", Map.of("since", "2999-01-01T00:00:00")));
        assertThat(items(futureWindow, "interactions")).isEmpty();
        Map<String, Object> futureSummary = (Map<String, Object>) futureWindow.get("summary");
        assertThat(futureSummary).containsEntry("returned_count", 0);
    }

    @Test
    void debugStartAndStopToggleDemoDebuggerSwitch() {
        assertThat(DEMO_DEBUGGER_ENABLED.get()).isFalse();

        createAndStart();

        assertThat(DEMO_DEBUGGER_ENABLED.get()).isTrue();

        Map<String, Object> stopped = post("/api/debug/stop", Map.of());

        assertThat(stopped).containsEntry("success", true).containsEntry("debugging", false);
        assertThat(DEMO_DEBUGGER_ENABLED.get()).isFalse();
    }

    @Test
    void debugStartFailsWhenDemoSwitchIsUnavailable() {
        writeSettings(1, 50);

        ResponseEntity<Map<String, Object>> response = rest.exchange("/api/debug/start", HttpMethod.POST,
                new HttpEntity<>(Map.of()), new ParameterizedTypeReference<>() {
                });

        assertThat(response.getStatusCode().value()).isEqualTo(400);
        assertThat(response.getBody()).containsEntry("success", false).containsEntry("debugging", false);
        assertThat(String.valueOf(response.getBody().get("message"))).contains("Java Demo");
        assertThat(get("/api/debug/state")).containsEntry("debugging", false).containsEntry("mode", "idle");
    }

    private static void writeSettings(int port, int timeoutMs) {
        try {
            Files.createDirectories(SETTINGS_FILE.getParent());
            String json = "{\"debugTarget\":{\"host\":\"127.0.0.1\",\"port\":"
                    + port
                    + ",\"debuggerSwitchPath\":\"/api/demo/debugger/enabled\",\"requestTimeoutMs\":"
                    + timeoutMs
                    + "}}";
            Files.writeString(SETTINGS_FILE, json, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Test
    void largePayloadIsChunkedAndSearchable() {
        createAndStart();
        post("/api/calls/before", makeBefore("large-call", "VNA", "acquire", 1,
                Map.of("voltage", 5.0, "data", List.of("payload-needle", "x".repeat(80_000)))));
        finish("large-call", true, 10);

        Map<String, Object> detail = get("/api/calls/large-call");
        assertThat((Number) detail.get("params_size")).matches(number -> number.intValue() > 64 * 1024);
        assertThat(detail).containsKey("paramsPayloadId");
        assertThat(detail).doesNotContainKey("params");

        Map<String, Object> chunk = get("/api/calls/large-call/payload?type=params&offset=0&limit=4096");
        assertThat(chunk).containsEntry("success", true);
        assertThat(chunk).containsEntry("hasMore", true);

        Map<String, Object> fragment = post("/api/agent/payloads/fragment", Map.of(
                "payload_ref", detail.get("paramsPayloadId"),
                "field_path", "request.parameters.voltage"));
        assertThat(fragment).containsEntry("ok", true);
        assertThat(fragment).containsEntry("status", "available");
        assertThat(((Number) fragment.get("value")).doubleValue()).isEqualTo(5.0);

        Map<String, Object> search = get("/api/calls/large-call/payload/search?type=params&q=payload-needle");
        assertThat(items(search, "matches")).isNotEmpty();
    }

    @Test
    void commandBreakpointPausesAndContinues() {
        createAndStart();
        post("/api/breakpoints", Map.of("objectName", "SA", "cmdName", "start", "slotId", 1, "matchMode", "command_only"));

        Map<String, Object> paused = post("/api/calls/before", makeBefore("paused-call", "SA", "start", 2, Map.of()));
        assertThat(paused).containsEntry("action", "pause");
        assertThat(get("/api/debug/state")).containsEntry("state", "DEBUGGING_PAUSED");

        Map<String, Object> continued = post("/api/calls/paused-call/continue", Map.of());
        assertThat(continued).containsEntry("success", true);
        assertThat(get("/api/calls/paused-call")).containsEntry("status", "continued");
    }

    @Test
    @SuppressWarnings("unchecked")
    void agentDeclareBreakpointRuleRegistersWithoutObservedInterface() {
        createAndStart();

        Map<String, Object> declared = post("/api/agent/breakpoints", Map.of(
                "target", Map.of("object", "VNA", "command", "initialize"),
                "match", Map.of("type", "interface")));
        assertThat(declared).containsEntry("ok", true);
        assertThat(declared).containsEntry("status", "armed");
        assertThat(declared).containsKey("breakpoint_rule_id");
        Map<String, Object> meta = (Map<String, Object>) declared.get("meta");
        Map<String, Object> hint = (Map<String, Object>) meta.get("observation_hint");
        assertThat(hint).containsEntry("state", "unobserved");
        assertThat(meta).containsEntry("reused", false);

        Map<String, Object> duplicate = post("/api/agent/breakpoints", Map.of(
                "target", Map.of("object", "VNA", "command", "initialize"),
                "match", Map.of("type", "interface")));
        assertThat(duplicate).containsEntry("breakpoint_rule_id", declared.get("breakpoint_rule_id"));
        Map<String, Object> duplicateMeta = (Map<String, Object>) duplicate.get("meta");
        assertThat(duplicateMeta).containsEntry("reused", true);
        assertThat(String.valueOf(duplicate.get("message"))).contains("复用");

        Map<String, Object> rules = get("/api/agent/breakpoints");
        assertThat(rules).containsEntry("ok", true);
        List<Map<String, Object>> breakpointRules = items(rules, "breakpoint_rules");
        assertThat(breakpointRules.get(0)).containsEntry("breakpoint_rule_id", declared.get("breakpoint_rule_id"));

        Map<String, Object> rule = get("/api/agent/breakpoints/" + declared.get("breakpoint_rule_id"));
        assertThat(rule).containsEntry("ok", true);
        assertThat(rule).containsEntry("status", "armed");

        Map<String, Object> disabled = post("/api/agent/breakpoints/" + declared.get("breakpoint_rule_id") + "/disable",
                Map.of());
        assertThat(disabled).containsEntry("ok", true);
        assertThat(disabled).containsEntry("status", "disabled");
        Map<String, Object> skipped = post("/api/calls/before",
                makeBefore("agent-vna-init-disabled", "VNA", "initialize", 1, Map.of()));
        assertThat(skipped).containsEntry("action", "continue");
        Map<String, Object> timeout = post("/api/agent/interactions/wait-paused", Map.of(
                "breakpoint_rule_id", declared.get("breakpoint_rule_id"),
                "target", Map.of("object", "VNA", "command", "initialize"),
                "timeout_ms", 1));
        assertThat(timeout).containsEntry("ok", false);
        assertThat(timeout).containsEntry("status", "timeout");

        Map<String, Object> enabled = post("/api/agent/breakpoints/" + declared.get("breakpoint_rule_id") + "/enable",
                Map.of());
        assertThat(enabled).containsEntry("ok", true);
        assertThat(enabled).containsEntry("status", "armed");

        Map<String, Object> cancelledWatch = post("/api/agent/interactions/paused/watch", Map.of(
                "target", Map.of("object", "VNA", "command", "initialize")));
        assertThat(cancelledWatch).containsEntry("ok", true);
        Map<String, Object> cancelled = delete("/api/agent/interactions/paused/watch/" + cancelledWatch.get("watch_id"));
        assertThat(cancelled).containsEntry("ok", true);
        assertThat(cancelled).containsEntry("status", "cancelled");

        Map<String, Object> watch = post("/api/agent/interactions/paused/watch", Map.of(
                "breakpoint_rule_id", declared.get("breakpoint_rule_id"),
                "target", Map.of("object", "VNA", "command", "initialize")));
        assertThat(watch).containsEntry("ok", true);
        assertThat(watch).containsEntry("status", "watching");

        Map<String, Object> paused = post("/api/calls/before",
                makeBefore("agent-vna-init", "VNA", "initialize", 1, Map.of("scenario", "vna-initialize")));
        assertThat(paused).containsEntry("action", "pause");

        Map<String, Object> events = get("/api/agent/events?watchId=" + watch.get("watch_id"));
        assertThat(events).containsEntry("ok", true);
        List<Map<String, Object>> watchEvents = items(events, "events");
        assertThat(watchEvents).hasSize(1);
        assertThat(watchEvents.get(0)).containsEntry("event", "interaction_paused");
        assertThat(watchEvents.get(0)).containsEntry("interaction_id", "agent-vna-init");
        assertThat(items(events, "entities")).anySatisfy(entity -> assertThat(entity)
                .containsEntry("type", "interaction")
                .containsEntry("id", "agent-vna-init"));

        Map<String, Object> explanation = post("/api/agent/breakpoints/" + declared.get("breakpoint_rule_id") + "/explain",
                Map.of("interaction_id", "agent-vna-init"));
        assertThat(explanation).containsEntry("ok", true);
        assertThat(explanation).containsEntry("matched", true);
        Map<String, Object> facts = (Map<String, Object>) explanation.get("facts");
        assertThat(facts).containsEntry("rule_enabled", true);
        assertThat(facts).containsEntry("target_matched", true);

        Map<String, Object> waited = post("/api/agent/interactions/wait-paused", Map.of(
                "breakpoint_rule_id", declared.get("breakpoint_rule_id"),
                "target", Map.of("object", "VNA", "command", "initialize"),
                "timeout_ms", 1));
        assertThat(waited).containsEntry("ok", true);
        assertThat(waited).containsEntry("status", "paused");
        assertThat(waited).containsEntry("interaction_id", "agent-vna-init");

        Map<String, Object> analysis = post("/api/agent/interactions/analyze", Map.of(
                "target", Map.of("object", "VNA", "command", "initialize")));
        assertThat(analysis).containsEntry("ok", true);
        List<Map<String, Object>> analyzed = items(analysis, "interactions");
        Map<String, Object> analyzedPaused = analyzed.stream()
                .filter(item -> "agent-vna-init".equals(item.get("interaction_id")))
                .findFirst()
                .orElseThrow();
        assertThat(analyzedPaused.get("request_payload_ref")).isNotNull();
        assertThat(items(analysis, "entities")).anySatisfy(entity -> {
            assertThat(entity).containsEntry("type", "interaction");
            assertThat(entity).containsEntry("id", "agent-vna-init");
        });

        Map<String, Object> compared = post("/api/agent/interactions/compare", Map.of(
                "interaction_ids", List.of("agent-vna-init-disabled", "agent-vna-init")));
        assertThat(compared).containsEntry("ok", true);
        assertThat(items(compared, "differences")).isNotEmpty();
        assertThat(items(compared, "entities")).extracting(item -> item.get("id"))
                .contains("agent-vna-init-disabled", "agent-vna-init");
        assertThat(items(compared, "entities")).anySatisfy(entity -> assertThat(entity)
                .containsEntry("type", "payload")
                .containsEntry("status", "available"));

        Map<String, Object> evidence = post("/api/agent/evidence", Map.of(
                "interaction_ids", List.of("agent-vna-init-disabled", "agent-vna-init"),
                "focus", "VNA 初始化断点命中证据"));
        assertThat(evidence).containsEntry("ok", true);
        assertThat(String.valueOf(evidence.get("evidence_bundle_id"))).startsWith("evb-");
        assertThat(items(evidence, "payload_refs")).isNotEmpty();
        assertThat(items(evidence, "differences")).isNotEmpty();
        assertThat(items(evidence, "entities")).anySatisfy(entity -> assertThat(entity)
                .containsEntry("type", "evidence_bundle"));

        Map<String, Object> pausedInteractions = post("/api/agent/interactions/paused/search", Map.of(
                "breakpoint_rule_id", declared.get("breakpoint_rule_id"),
                "target", Map.of("object", "VNA", "command", "initialize")));
        assertThat(pausedInteractions).containsEntry("ok", true);
        List<Map<String, Object>> interactions = items(pausedInteractions, "interactions");
        assertThat(interactions).hasSize(1);
        assertThat(interactions.get(0)).containsEntry("interaction_id", "agent-vna-init");

        Map<String, Object> continued = post("/api/agent/interactions/agent-vna-init/continue", Map.of());
        assertThat(continued).containsEntry("ok", true);
        assertThat(continued).containsEntry("status", "continued");
        assertThat(get("/api/calls/agent-vna-init")).containsEntry("status", "continued");

        Map<String, Object> deleted = delete("/api/agent/breakpoints/" + declared.get("breakpoint_rule_id"));
        assertThat(deleted).containsEntry("ok", true);
        assertThat(deleted).containsEntry("status", "cancelled");
        Map<String, Object> afterDelete = post("/api/calls/before",
                makeBefore("agent-vna-init-after-delete", "VNA", "initialize", 1, Map.of()));
        assertThat(afterDelete).containsEntry("action", "continue");
    }

    @Test
    void agentParameterBreakpointComparesValuesAtRuntime() {
        createAndStart();

        Map<String, Object> declared = post("/api/agent/breakpoints", Map.of(
                "target", Map.of("object", "PSU", "command", "set_voltage"),
                "match", Map.of(
                        "type", "parameters",
                        "conditions", List.of(Map.of(
                                "path", "parameters.voltage",
                                "op", "gt",
                                "value", 5),
                                Map.of("path", "parameters.mode", "op", "exists")))));
        assertThat(declared).containsEntry("ok", true);
        assertThat(declared).containsEntry("status", "armed");

        Map<String, Object> duplicate = post("/api/agent/breakpoints", Map.of(
                "target", Map.of("object", "PSU", "command", "set_voltage"),
                "match", Map.of(
                        "type", "parameters",
                        "conditions", List.of(Map.of(
                                "path", "parameters.voltage",
                                "op", "gt",
                                "value", 5),
                                Map.of("path", "parameters.mode", "op", "exists")))));
        assertThat(duplicate).containsEntry("breakpoint_rule_id", declared.get("breakpoint_rule_id"));
        Map<String, Object> duplicateMeta = (Map<String, Object>) duplicate.get("meta");
        assertThat(duplicateMeta).containsEntry("reused", true);
        assertThat(String.valueOf(duplicate.get("message"))).contains("复用");

        Map<String, Object> below = post("/api/calls/before",
                makeBefore("psu-voltage-low", "PSU", "set_voltage", 1, Map.of("voltage", 4.5, "mode", "fast")));
        assertThat(below).containsEntry("action", "continue");

        Map<String, Object> hit = post("/api/calls/before",
                makeBefore("psu-voltage-high", "PSU", "set_voltage", 1, Map.of("voltage", 6.0, "mode", "fast")));
        assertThat(hit).containsEntry("action", "pause");
        assertThat(hit).containsEntry("breakpointId", declared.get("breakpoint_rule_id"));

        Map<String, Object> explanation = post("/api/agent/breakpoints/" + declared.get("breakpoint_rule_id")
                + "/explain", Map.of("interaction_id", "psu-voltage-high"));
        assertThat(explanation).containsEntry("matched", true);
        Map<String, Object> facts = (Map<String, Object>) explanation.get("facts");
        assertThat(facts).containsEntry("slot_matched", true);
        assertThat(items(explanation, "condition_results"))
                .extracting(item -> item.get("matched"))
                .containsExactly(true, true);
    }

    @Test
    void explainBreakpointMatchRespectsExplicitSlotFilter() {
        createAndStart();
        Map<String, Object> created = post("/api/breakpoints", Map.of(
                "objectName", "VNA",
                "cmdName", "create",
                "slotId", 1,
                "matchMode", "params_condition",
                "conditions", List.of(Map.of("path", "params.mode", "operator", "eq", "value", "A"))));
        assertThat(created).containsEntry("success", true);

        Map<String, Object> missedSlot = post("/api/calls/before",
                makeBefore("explain-miss-slot", "VNA", "create", 2, Map.of("mode", "A")));
        assertThat(missedSlot).containsEntry("action", "continue");

        Map<String, Object> explanation = post("/api/agent/breakpoints/" + created.get("breakpointId") + "/explain",
                Map.of("interaction_id", "explain-miss-slot"));
        assertThat(explanation).containsEntry("matched", false);
        Map<String, Object> facts = (Map<String, Object>) explanation.get("facts");
        assertThat(facts).containsEntry("target_matched", true);
        assertThat(facts).containsEntry("slot_matched", false);
    }

    @Test
    void paramsSnapshotBreakpointMatchesSlotAndParams() {
        createAndStart();
        post("/api/calls/before", makeBefore("seed-call", "VNA", "create", 1, Map.of("mode", "A")));
        finish("seed-call", true, 5);
        post("/api/calls/seed-call/breakpoint", Map.of("matchMode", "params_snapshot", "hitMode", "always"));

        Map<String, Object> missedSlot = post("/api/calls/before",
                makeBefore("miss-slot", "VNA", "create", 2, Map.of("mode", "A")));
        assertThat(missedSlot).containsEntry("action", "continue");

        Map<String, Object> missedParams = post("/api/calls/before",
                makeBefore("miss-params", "VNA", "create", 1, Map.of("mode", "B")));
        assertThat(missedParams).containsEntry("action", "continue");

        Map<String, Object> hit = post("/api/calls/before",
                makeBefore("hit-snapshot", "VNA", "create", 1, Map.of("mode", "A")));
        assertThat(hit).containsEntry("action", "pause");
    }

    @Test
    void interfaceLockMarksUnregisteredCalls() {
        createAndStart();
        post("/api/interfaces/lock", Map.of("locked", true));

        post("/api/calls/before", makeBefore("locked-call", "SA", "newCommand", 1, Map.of("mode", "A")));
        List<Map<String, Object>> calls = items(get("/api/calls"));
        assertThat(items(get("/api/interfaces"))).isEmpty();
        assertThat(calls.get(0)).containsEntry("interface_registered", 0);

        Map<String, Object> registered = post("/api/calls/locked-call/interface", Map.of());
        assertThat(registered).containsEntry("success", true);
        assertThat(items(get("/api/interfaces"))).hasSize(1);
    }

    @Test
    void clearCallRecordsKeepsInterfacesAndBreakpoints() {
        createAndStart();
        post("/api/calls/before", makeBefore("record-only-clear", "SA", "start", 1, Map.of("mode", "A")));
        finish("record-only-clear", true, 5);
        Map<String, Object> interfaceItem = items(get("/api/interfaces")).get(0);
        post("/api/interfaces/" + interfaceItem.get("id") + "/breakpoint", Map.of());
        post("/api/debug/stop", Map.of());

        Map<String, Object> cleared = post("/api/calls/clear", Map.of());
        assertThat(cleared).containsEntry("success", true);
        assertThat((Map<String, Object>) cleared.get("deletedCount")).containsEntry("calls", 1);
        assertThat(items(get("/api/calls"))).isEmpty();
        assertThat(items(get("/api/interfaces"))).hasSize(1);
        assertThat(items(get("/api/breakpoints"))).hasSize(1);
    }

    @Test
    void archiveFileRoundTripKeepsLargePayloadReadable() {
        Map<String, Object> created = post("/api/sessions", Map.of());
        String sessionId = String.valueOf(created.get("sessionId"));
        post("/api/debug/start", Map.of());
        post("/api/calls/before", makeBefore("archive-large", "VNA", "acquire", 1, Map.of("mode", "A")));
        finish("archive-large", true, 10);

        ResponseEntity<byte[]> exported = rest.exchange("/api/sessions/" + sessionId + "/export-file",
                HttpMethod.POST, new HttpEntity<>(Map.of("archiveName", "large archive")), byte[].class);
        assertThat(exported.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(exported.getBody()).startsWith(new byte[] { 'P', 'K' });

        rest.postForObject("/api/debug/stop", Map.of(), Map.class);
        rest.exchange("/api/sessions", HttpMethod.DELETE, HttpEntity.EMPTY, Map.class);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_OCTET_STREAM);
        ResponseEntity<Map<String, Object>> imported = rest.exchange("/api/sessions/import-file?lockInterfaces=1",
                HttpMethod.POST, new HttpEntity<>(exported.getBody(), headers), new ParameterizedTypeReference<>() {
                });
        assertThat(imported.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(imported.getBody()).containsEntry("success", true).containsEntry("interfaceLocked", true);

        List<Map<String, Object>> calls = items(get("/api/calls"));
        assertThat(calls).hasSize(1);
        Map<String, Object> chunk = get("/api/calls/" + calls.get(0).get("call_id") + "/payload?type=result&limit=4096");
        assertThat(chunk).containsEntry("success", true);
        assertThat(String.valueOf(chunk.get("content"))).contains("\"ok\":true");
    }

    private void createAndStart() {
        post("/api/sessions", Map.of());
        Map<String, Object> started = post("/api/debug/start", Map.of());
        assertThat(started).containsEntry("state", "DEBUGGING");
    }

    private static HttpServer startDemoServer() {
        try {
            HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            server.createContext("/api/demo/debugger/enabled", exchange -> {
                String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
                DEMO_DEBUGGER_ENABLED.set(body.contains("\"enabled\":true"));
                byte[] response = ("{\"success\":true,\"enabled\":"
                        + DEMO_DEBUGGER_ENABLED.get() + "}").getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", "application/json;charset=UTF-8");
                exchange.sendResponseHeaders(200, response.length);
                try (java.io.OutputStream outputStream = exchange.getResponseBody()) {
                    outputStream.write(response);
                }
            });
            server.start();
            return server;
        } catch (Exception e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    private void finish(String callId, boolean success, int costMs) {
        post("/api/calls/after", Map.of(
                "callId", callId,
                "success", success,
                "costMs", costMs,
                "result", Map.of("ok", success)));
    }

    private Map<String, Object> makeBefore(String callId, String objectName, String cmdName, Integer slotId,
            Map<String, Object> params) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("callId", callId);
        body.put("objectName", objectName);
        body.put("cmdName", cmdName);
        body.put("slotId", slotId);
        body.put("description", objectName + " " + cmdName);
        body.put("params", params);
        body.put("serviceName", "instrument-service-demo");
        body.put("className", "com.example.instrumentdemo.service.InstrumentServiceImpl");
        body.put("methodName", "instrumentControl");
        body.put("displayName", "仪表控制");
        body.put("threadName", "test");
        body.put("rawArgs", Map.of("objectName", objectName, "cmdName", cmdName, "slotId", slotId, "params", params));
        body.put("parameterMeta", List.of(Map.of("name", "params", "javaType", "java.util.Map")));
        return body;
    }

    private Map<String, Object> get(String path) {
        ResponseEntity<Map<String, Object>> response = rest.exchange(path, HttpMethod.GET, HttpEntity.EMPTY,
                new ParameterizedTypeReference<>() {
                });
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        return response.getBody();
    }

    private Map<String, Object> post(String path, Map<String, Object> body) {
        ResponseEntity<Map<String, Object>> response = rest.exchange(path, HttpMethod.POST, new HttpEntity<>(body),
                new ParameterizedTypeReference<>() {
                });
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        return response.getBody();
    }

    private Map<String, Object> delete(String path) {
        ResponseEntity<Map<String, Object>> response = rest.exchange(path, HttpMethod.DELETE, HttpEntity.EMPTY,
                new ParameterizedTypeReference<>() {
                });
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        return response.getBody();
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> items(Map<String, Object> payload) {
        return (List<Map<String, Object>>) payload.get("items");
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> items(Map<String, Object> payload, String key) {
        return (List<Map<String, Object>>) payload.get(key);
    }
}
