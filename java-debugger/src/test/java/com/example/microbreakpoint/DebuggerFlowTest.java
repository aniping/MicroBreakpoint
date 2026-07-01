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
                Map.of("data", List.of("payload-needle", "x".repeat(80_000)))));
        finish("large-call", true, 10);

        Map<String, Object> detail = get("/api/calls/large-call");
        assertThat((Number) detail.get("params_size")).matches(number -> number.intValue() > 64 * 1024);
        assertThat(detail).containsKey("paramsPayloadId");
        assertThat(detail).doesNotContainKey("params");

        Map<String, Object> chunk = get("/api/calls/large-call/payload?type=params&offset=0&limit=4096");
        assertThat(chunk).containsEntry("success", true);
        assertThat(chunk).containsEntry("hasMore", true);

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

        Map<String, Object> duplicate = post("/api/agent/breakpoints", Map.of(
                "target", Map.of("object", "VNA", "command", "initialize"),
                "match", Map.of("type", "interface")));
        assertThat(duplicate).containsEntry("breakpoint_rule_id", declared.get("breakpoint_rule_id"));

        Map<String, Object> paused = post("/api/calls/before",
                makeBefore("agent-vna-init", "VNA", "initialize", 1, Map.of("scenario", "vna-initialize")));
        assertThat(paused).containsEntry("action", "pause");

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

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> items(Map<String, Object> payload) {
        return (List<Map<String, Object>>) payload.get("items");
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> items(Map<String, Object> payload, String key) {
        return (List<Map<String, Object>>) payload.get(key);
    }
}
