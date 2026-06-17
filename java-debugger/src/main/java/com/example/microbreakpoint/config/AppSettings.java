package com.example.microbreakpoint.config;

import java.nio.file.Files;
import java.nio.file.Path;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.springframework.stereotype.Component;

@Component
public class AppSettings {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private final DebuggerProperties properties;

    public AppSettings(DebuggerProperties properties) {
        this.properties = properties;
    }

    public DebugTarget debugTarget() {
        JsonNode target = readRoot().path("debugTarget");
        String host = text(target, "host", "127.0.0.1").trim();
        if (host.isBlank()) {
            host = "127.0.0.1";
        }
        String path = text(target, "debuggerSwitchPath", "/api/demo/debugger/enabled").trim();
        if (path.isBlank()) {
            path = "/api/demo/debugger/enabled";
        }
        if (!path.startsWith("/")) {
            path = "/" + path;
        }
        return new DebugTarget(
                host,
                intInRange(target.path("port"), 8080, 1, 65535),
                path,
                intInRange(target.path("requestTimeoutMs"), 1000, 1, 600000));
    }

    private JsonNode readRoot() {
        String settingsFile = properties.getSettingsFile();
        if (settingsFile == null || settingsFile.isBlank()) {
            return OBJECT_MAPPER.createObjectNode();
        }
        Path path = Path.of(settingsFile).toAbsolutePath();
        if (!Files.isRegularFile(path)) {
            return OBJECT_MAPPER.createObjectNode();
        }
        try {
            return OBJECT_MAPPER.readTree(path.toFile());
        } catch (Exception e) {
            return OBJECT_MAPPER.createObjectNode();
        }
    }

    private static String text(JsonNode node, String field, String defaultValue) {
        JsonNode value = node.path(field);
        return value.isTextual() ? value.asText() : defaultValue;
    }

    private static int intInRange(JsonNode node, int defaultValue, int minimum, int maximum) {
        int value = node.isInt() || node.isLong() || node.isTextual() ? node.asInt(defaultValue) : defaultValue;
        if (value < minimum || value > maximum) {
            return defaultValue;
        }
        return value;
    }

    public record DebugTarget(String host, int port, String debuggerSwitchPath, int requestTimeoutMs) {
        public String debugSwitchUrl() {
            String baseUrl = host.endsWith("/") ? host.substring(0, host.length() - 1) : host;
            if (!baseUrl.contains("://")) {
                baseUrl = "http://" + baseUrl + ":" + port;
            }
            return trimTrailingSlash(baseUrl) + debuggerSwitchPath;
        }

        private static String trimTrailingSlash(String value) {
            String result = value.trim();
            while (result.endsWith("/")) {
                result = result.substring(0, result.length() - 1);
            }
            return result;
        }
    }
}
