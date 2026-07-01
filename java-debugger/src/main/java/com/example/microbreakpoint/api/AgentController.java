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

@CrossOrigin
@RestController
@RequestMapping("/api/agent")
public class AgentController {

    private final DebugService debugService;

    public AgentController(DebugService debugService) {
        this.debugService = debugService;
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
}
