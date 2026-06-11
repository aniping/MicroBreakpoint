package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.service.DebugService;

@CrossOrigin
@RestController
@RequestMapping("/api/breakpoints")
public class BreakpointController {

    private final DebugService debugService;

    public BreakpointController(DebugService debugService) {
        this.debugService = debugService;
    }

    @GetMapping("")
    public Map<String, Object> breakpoints(@RequestParam(required = false) String sessionId) {
        return Map.of("items", debugService.listBreakpoints(sessionId));
    }

    @PostMapping("")
    public ResponseEntity<Map<String, Object>> add(@RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = debugService.createBreakpoint(body == null ? Map.of() : body);
        int status = Boolean.TRUE.equals(result.get("success")) ? 200
                : String.valueOf(result.getOrDefault("code", "")).startsWith("DUPLICATE_") ? 409 : 400;
        return ResponseEntity.status(status).body(result);
    }

    @DeleteMapping("/{breakpointId}")
    public Map<String, Object> delete(@PathVariable String breakpointId) {
        debugService.deleteBreakpoint(breakpointId);
        return Map.of("success", true);
    }

    @PostMapping("/{breakpointId}/enable")
    public Map<String, Object> enable(@PathVariable String breakpointId) {
        debugService.setBreakpointEnabled(breakpointId, true);
        return Map.of("success", true);
    }

    @PostMapping("/{breakpointId}/disable")
    public Map<String, Object> disable(@PathVariable String breakpointId) {
        debugService.setBreakpointEnabled(breakpointId, false);
        return Map.of("success", true);
    }
}
