package com.example.microbreakpoint.api;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Map;

import com.fasterxml.jackson.databind.ObjectMapper;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.config.AppSettings;
import com.example.microbreakpoint.service.DebugService;

@CrossOrigin
@RestController
@RequestMapping("/api/debug")
public class DebugController {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    private final DebugService debugService;
    private final AppSettings appSettings;

    public DebugController(DebugService debugService, AppSettings appSettings) {
        this.debugService = debugService;
        this.appSettings = appSettings;
    }

    @GetMapping("/state")
    public Map<String, Object> state() {
        return debugService.stateResponse();
    }

    @PostMapping("/start")
    public ResponseEntity<Map<String, Object>> start(@RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> switchResult = setDemoDebuggerEnabled(true);
        if (!Boolean.TRUE.equals(switchResult.get("success"))) {
            return ResponseEntity.status(400).body(debugService.stateResponse(DebugService.mapOf(
                    "success", false,
                    "message", switchResult.get("message"))));
        }
        Map<String, Object> result = debugService.startDebug(body == null ? Map.of() : body);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 400).body(result);
    }

    @PostMapping("/stop")
    public ResponseEntity<Map<String, Object>> stop() {
        int released = debugService.stopDebug();
        Map<String, Object> switchResult = setDemoDebuggerEnabled(false);
        boolean success = Boolean.TRUE.equals(switchResult.get("success"));
        Map<String, Object> result = debugService.stateResponse(DebugService.mapOf(
                "success", success,
                "releasedCount", released,
                "message", success ? "调试已停止" : switchResult.get("message")));
        return ResponseEntity.status(success ? 200 : 400).body(result);
    }

    @PostMapping("/reset")
    public Map<String, Object> reset() {
        return debugService.resetDebug();
    }

    private Map<String, Object> setDemoDebuggerEnabled(boolean enabled) {
        AppSettings.DebugTarget target = appSettings.debugTarget();
        String url = target.debugSwitchUrl();
        if (url == null || url.isBlank()) {
            return DebugService.mapOf("success", false, "message", "Java Demo 地址未配置");
        }
        HttpURLConnection connection = null;
        try {
            byte[] body = OBJECT_MAPPER.writeValueAsString(Map.of("enabled", enabled))
                    .getBytes(StandardCharsets.UTF_8);
            connection = (HttpURLConnection) new URL(url).openConnection();
            connection.setRequestMethod("POST");
            int timeoutMs = Math.max(1, target.requestTimeoutMs());
            connection.setConnectTimeout(timeoutMs);
            connection.setReadTimeout(timeoutMs);
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            connection.setRequestProperty("Accept", "application/json");
            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(body);
            }
            int status = connection.getResponseCode();
            String responseText = readResponse(connection, status);
            if (status < 200 || status >= 300) {
                return DebugService.mapOf("success", false, "message",
                        "Java Demo 调试开关请求失败：HTTP " + status + responseSuffix(responseText));
            }
            return DebugService.mapOf("success", true);
        } catch (Exception e) {
            return DebugService.mapOf("success", false, "message",
                    "无法连接 Java Demo 调试开关：" + e.getMessage());
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private static String readResponse(HttpURLConnection connection, int status) {
        try {
            InputStream stream = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
            if (stream == null) {
                return "";
            }
            try (stream) {
                return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
            }
        } catch (Exception e) {
            return "";
        }
    }

    private static String responseSuffix(String responseText) {
        return responseText == null || responseText.isBlank() ? "" : "，响应：" + responseText;
    }
}
