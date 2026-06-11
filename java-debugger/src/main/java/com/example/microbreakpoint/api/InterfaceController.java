package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.service.DebugService;

@CrossOrigin
@RestController
@RequestMapping("/api/interfaces")
public class InterfaceController {

    private final DebugService debugService;

    public InterfaceController(DebugService debugService) {
        this.debugService = debugService;
    }

    @GetMapping("")
    public Map<String, Object> interfaces(@RequestParam(required = false) String sessionId,
            @RequestParam(required = false) String objectName,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String sortBy,
            @RequestParam(required = false) String sortOrder,
            @RequestParam(required = false) String page,
            @RequestParam(required = false) String pageSize) {
        return debugService.listInterfaces(sessionId, objectName, keyword, status, sortBy, sortOrder, page, pageSize);
    }

    @GetMapping("/grouped")
    public Map<String, Object> grouped(@RequestParam(required = false) String sessionId) {
        return debugService.groupedInterfaces(sessionId);
    }

    @GetMapping("/lock")
    public Map<String, Object> lockState() {
        return debugService.stateResponse();
    }

    @PostMapping("/lock")
    public Map<String, Object> updateLock(@RequestBody(required = false) Map<String, Object> body) {
        Object locked = body == null ? false : body.get("locked");
        return debugService.setInterfaceLocked(Boolean.TRUE.equals(locked) || "true".equalsIgnoreCase(String.valueOf(locked))
                || "1".equals(String.valueOf(locked)));
    }

    @GetMapping("/{interfaceId}")
    public ResponseEntity<Map<String, Object>> detail(@PathVariable String interfaceId) {
        Map<String, Object> result = debugService.interfaceDetail(interfaceId);
        return result == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "not found"))
                : ResponseEntity.ok(result);
    }

    @GetMapping("/{interfaceId}/samples")
    public Map<String, Object> samples(@PathVariable String interfaceId,
            @RequestParam(defaultValue = "10") String limit,
            @RequestParam(defaultValue = "0") String offset) {
        return debugService.interfaceSamples(interfaceId, limit, offset);
    }

    @GetMapping("/{interfaceId}/breakpoints")
    public ResponseEntity<Map<String, Object>> breakpoints(@PathVariable String interfaceId) {
        var items = debugService.listInterfaceBreakpoints(interfaceId);
        return items == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "not found"))
                : ResponseEntity.ok(Map.of("success", true, "items", items));
    }

    @PatchMapping("/{interfaceId}/alias")
    public ResponseEntity<Map<String, Object>> alias(@PathVariable String interfaceId,
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = debugService.updateInterfaceAlias(interfaceId,
                body == null ? "" : String.valueOf(body.getOrDefault("alias", "")));
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 404).body(result);
    }

    @PostMapping("/{interfaceId}/breakpoint")
    public ResponseEntity<Map<String, Object>> breakpoint(@PathVariable String interfaceId,
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = debugService.breakpointFromInterface(interfaceId, body == null ? Map.of() : body);
        int status = Boolean.TRUE.equals(result.get("success")) ? 200
                : String.valueOf(result.getOrDefault("code", "")).startsWith("DUPLICATE_") ? 409 : 404;
        return ResponseEntity.status(status).body(result);
    }
}
