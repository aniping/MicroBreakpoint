package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.service.DebugService;
import com.example.microbreakpoint.service.PayloadService;

@CrossOrigin
@RestController
@RequestMapping("/api/agent")
public class AgentController {

    private final DebugService debugService;
    private final PayloadService payloadService;

    public AgentController(DebugService debugService, PayloadService payloadService) {
        this.debugService = debugService;
        this.payloadService = payloadService;
    }

    @PostMapping("/breakpoints")
    public ResponseEntity<Map<String, Object>> declareBreakpoint(
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = debugService.declareBreakpointRule(body == null ? Map.of() : body);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("ok")) ? 200 : 400).body(result);
    }

    @PostMapping("/interactions/paused/search")
    public Map<String, Object> pausedInteractions(@RequestBody(required = false) Map<String, Object> body) {
        return debugService.listPausedInteractions(body == null ? Map.of() : body);
    }

    @PostMapping("/interactions/{interactionId}/continue")
    public ResponseEntity<Map<String, Object>> continueInteraction(@PathVariable String interactionId) {
        Map<String, Object> result = debugService.continuePausedInteraction(interactionId);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("ok")) ? 200 : 400).body(result);
    }

    @PostMapping("/payloads/fragment")
    public ResponseEntity<Map<String, Object>> payloadFragment(
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = payloadService.payloadFragment(body == null ? Map.of() : body);
        int status = Boolean.TRUE.equals(result.get("ok")) ? 200 : "not_found".equals(result.get("status")) ? 404 : 400;
        return ResponseEntity.status(status).body(result);
    }
}
