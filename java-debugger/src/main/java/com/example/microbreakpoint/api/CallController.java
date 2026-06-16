package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.config.DebuggerProperties;
import com.example.microbreakpoint.service.DebugService;
import com.example.microbreakpoint.service.PayloadService;
import com.example.microbreakpoint.service.WaitManager;

@CrossOrigin
@RestController
@RequestMapping("/api/calls")
public class CallController {

    private final DebugService debugService;
    private final PayloadService payloadService;
    private final WaitManager waitManager;
    private final DebuggerProperties properties;

    public CallController(DebugService debugService, PayloadService payloadService, WaitManager waitManager,
            DebuggerProperties properties) {
        this.debugService = debugService;
        this.payloadService = payloadService;
        this.waitManager = waitManager;
        this.properties = properties;
    }

    @PostMapping("/before")
    public Map<String, Object> before(@RequestBody(required = false) Map<String, Object> body) {
        return debugService.beforeCall(body == null ? Map.of() : body);
    }

    @PostMapping("/after")
    public Map<String, Object> after(@RequestBody(required = false) Map<String, Object> body) {
        return debugService.afterCall(body == null ? Map.of() : body);
    }

    @GetMapping("")
    public Map<String, Object> calls(@RequestParam(required = false) String sessionId,
            @RequestParam(required = false) String objectName,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String sortBy,
            @RequestParam(required = false) String sortOrder,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String pageSize) {
        return debugService.listCalls(sessionId, objectName, keyword, status, sortBy, sortOrder, page, pageSize);
    }

    @GetMapping("/grouped")
    public Map<String, Object> grouped(@RequestParam(required = false) String sessionId) {
        return debugService.groupedCalls(sessionId);
    }

    @PostMapping("/clear")
    public ResponseEntity<Map<String, Object>> clear() {
        Map<String, Object> result = debugService.clearCallRecords();
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 400).body(result);
    }

    @GetMapping("/{callId}")
    public ResponseEntity<Map<String, Object>> detail(@PathVariable String callId) {
        Map<String, Object> result = debugService.callDetail(callId);
        return result == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "not found"))
                : ResponseEntity.ok(result);
    }

    @GetMapping("/{callId}/payload")
    public ResponseEntity<Map<String, Object>> payload(@PathVariable String callId,
            @RequestParam(defaultValue = "params") String type,
            @RequestParam(defaultValue = "0") String offset,
            @RequestParam(defaultValue = "8192") String limit) {
        Map<String, Object> result = payloadService.payloadChunk(callId, type, offset, limit);
        return result == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "payload not found"))
                : ResponseEntity.ok(result);
    }

    @GetMapping("/{callId}/payload/export")
    public ResponseEntity<Resource> exportPayload(@PathVariable String callId,
            @RequestParam(defaultValue = "params") String type) {
        Map<String, Object> row = payloadService.exportPayloadTarget(callId, type);
        if (row == null) {
            return ResponseEntity.notFound().build();
        }
        String filename = "json".equals(row.getOrDefault("content_format", "json")) ? type + ".json" : type + ".txt";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + filename)
                .contentType(filename.endsWith(".json") ? MediaType.APPLICATION_JSON : MediaType.TEXT_PLAIN)
                .body(payloadService.resourceFor(row));
    }

    @GetMapping("/{callId}/payload/search")
    public ResponseEntity<Map<String, Object>> searchPayload(@PathVariable String callId,
            @RequestParam(defaultValue = "params") String type,
            @RequestParam(defaultValue = "") String q) {
        Map<String, Object> result = payloadService.searchPayload(callId, type, q);
        return result == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "payload not found"))
                : ResponseEntity.ok(result);
    }

    @GetMapping("/{callId}/wait")
    public Map<String, Object> waitCall(@PathVariable String callId) {
        String action = waitManager.waitFor(callId, properties.getBreakpointTimeoutSeconds());
        if ("timeout_continue".equals(action)) {
            debugService.jdbc().update("UPDATE call_record SET status='timeout' WHERE call_id=?", callId);
        }
        return Map.of("action", action);
    }

    @PostMapping("/{callId}/continue")
    public Map<String, Object> continueCall(@PathVariable String callId) {
        return debugService.continueCall(callId);
    }

    @PostMapping("/continue-all")
    public Map<String, Object> continueAll() {
        return debugService.continueAllCalls();
    }

    @PostMapping("/{callId}/interface")
    public ResponseEntity<Map<String, Object>> registerInterface(@PathVariable String callId) {
        Map<String, Object> result = debugService.registerInterfaceFromCall(callId);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 404).body(result);
    }

    @PostMapping("/{callId}/breakpoint")
    public ResponseEntity<Map<String, Object>> breakpointFromCall(@PathVariable String callId,
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = debugService.breakpointFromCall(callId, body == null ? Map.of() : body);
        int status = Boolean.TRUE.equals(result.get("success")) ? 200
                : String.valueOf(result.getOrDefault("code", "")).startsWith("DUPLICATE_") ? 409 : 404;
        return ResponseEntity.status(status).body(result);
    }
}
