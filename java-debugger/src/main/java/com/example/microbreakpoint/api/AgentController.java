package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.http.HttpStatus;
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

import com.example.microbreakpoint.service.AgentBreakpointService;
import com.example.microbreakpoint.service.AgentBreakpointExplanationService;
import com.example.microbreakpoint.service.AgentInteractionAnalysisService;
import com.example.microbreakpoint.service.AgentPausedInteractionService;
import com.example.microbreakpoint.service.AgentPausedInteractionWatchService;
import com.example.microbreakpoint.service.PayloadService;

@CrossOrigin
@RestController
@RequestMapping("/api/agent")
public class AgentController {

    private final PayloadService payloadService;
    private final AgentBreakpointService agentBreakpointService;
    private final AgentBreakpointExplanationService agentBreakpointExplanationService;
    private final AgentPausedInteractionService agentPausedInteractionService;
    private final AgentPausedInteractionWatchService agentPausedInteractionWatchService;
    private final AgentInteractionAnalysisService agentInteractionAnalysisService;

    public AgentController(PayloadService payloadService,
            AgentBreakpointService agentBreakpointService, AgentBreakpointExplanationService agentBreakpointExplanationService,
            AgentPausedInteractionService agentPausedInteractionService,
            AgentPausedInteractionWatchService agentPausedInteractionWatchService,
            AgentInteractionAnalysisService agentInteractionAnalysisService) {
        this.payloadService = payloadService;
        this.agentBreakpointService = agentBreakpointService;
        this.agentBreakpointExplanationService = agentBreakpointExplanationService;
        this.agentPausedInteractionService = agentPausedInteractionService;
        this.agentPausedInteractionWatchService = agentPausedInteractionWatchService;
        this.agentInteractionAnalysisService = agentInteractionAnalysisService;
    }

    @PostMapping("/breakpoints")
    public ResponseEntity<Map<String, Object>> declareBreakpoint(
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = agentBreakpointService.declare(body == null ? Map.of() : body);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("ok")) ? 200 : 400).body(result);
    }

    @GetMapping("/breakpoints")
    public Map<String, Object> breakpoints(@RequestParam(required = false) String sessionId) {
        return agentBreakpointService.list(sessionId);
    }

    @GetMapping("/breakpoints/{ruleId}")
    public ResponseEntity<Map<String, Object>> breakpoint(@PathVariable String ruleId) {
        return agentResponse(agentBreakpointService.get(ruleId));
    }

    @PostMapping("/breakpoints/{ruleId}/disable")
    public ResponseEntity<Map<String, Object>> disableBreakpoint(@PathVariable String ruleId) {
        return agentResponse(agentBreakpointService.setEnabled(ruleId, false));
    }

    @PostMapping("/breakpoints/{ruleId}/enable")
    public ResponseEntity<Map<String, Object>> enableBreakpoint(@PathVariable String ruleId) {
        return agentResponse(agentBreakpointService.setEnabled(ruleId, true));
    }

    @DeleteMapping("/breakpoints/{ruleId}")
    public ResponseEntity<Map<String, Object>> deleteBreakpoint(@PathVariable String ruleId) {
        return agentResponse(agentBreakpointService.delete(ruleId));
    }

    @PostMapping("/breakpoints/{ruleId}/explain")
    public ResponseEntity<Map<String, Object>> explainBreakpoint(@PathVariable String ruleId,
            @RequestBody(required = false) Map<String, Object> body) {
        return agentResponse(agentBreakpointExplanationService.explain(ruleId, body == null ? Map.of() : body));
    }

    @PostMapping("/interactions/paused/search")
    public Map<String, Object> pausedInteractions(@RequestBody(required = false) Map<String, Object> body) {
        return agentPausedInteractionService.list(body == null ? Map.of() : body);
    }

    @PostMapping("/interactions/wait-paused")
    public ResponseEntity<Map<String, Object>> waitPausedInteraction(
            @RequestBody(required = false) Map<String, Object> body) {
        return ResponseEntity.ok(agentPausedInteractionService.waitPaused(body == null ? Map.of() : body));
    }

    @PostMapping("/interactions/paused/watch")
    public ResponseEntity<Map<String, Object>> watchPausedInteraction(
            @RequestBody(required = false) Map<String, Object> body) {
        return agentResponse(agentPausedInteractionWatchService.watch(body == null ? Map.of() : body));
    }

    @DeleteMapping("/interactions/paused/watch/{watchId}")
    public ResponseEntity<Map<String, Object>> cancelPausedInteractionWatch(@PathVariable String watchId) {
        return agentResponse(agentPausedInteractionWatchService.cancel(watchId));
    }

    @GetMapping("/events")
    public Map<String, Object> events(@RequestParam(required = false) String watchId,
            @RequestParam(name = "watch_id", required = false) String watchIdSnake,
            @RequestParam(required = false) String afterEventId,
            @RequestParam(name = "after_event_id", required = false) String afterEventIdSnake) {
        return agentPausedInteractionWatchService.listEvents(firstNonBlank(watchId, watchIdSnake),
                firstNonBlank(afterEventId, afterEventIdSnake));
    }

    @PostMapping("/interactions/{interactionId}/continue")
    public ResponseEntity<Map<String, Object>> continueInteraction(@PathVariable String interactionId) {
        Map<String, Object> result = agentPausedInteractionService.continueInteraction(interactionId);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("ok")) ? 200 : 400).body(result);
    }

    @PostMapping("/interactions/analyze")
    public Map<String, Object> analyzeInteractions(@RequestBody(required = false) Map<String, Object> body) {
        return agentInteractionAnalysisService.analyze(body == null ? Map.of() : body);
    }

    @PostMapping("/interactions/compare")
    public ResponseEntity<Map<String, Object>> compareInteractions(
            @RequestBody(required = false) Map<String, Object> body) {
        return agentResponse(agentInteractionAnalysisService.compare(body == null ? Map.of() : body));
    }

    @PostMapping("/payloads/fragment")
    public ResponseEntity<Map<String, Object>> payloadFragment(
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = payloadService.payloadFragment(body == null ? Map.of() : body);
        int status = Boolean.TRUE.equals(result.get("ok")) ? 200 : "not_found".equals(result.get("status")) ? 404 : 400;
        return ResponseEntity.status(status).body(result);
    }

    private ResponseEntity<Map<String, Object>> agentResponse(Map<String, Object> result) {
        HttpStatus status = Boolean.TRUE.equals(result.get("ok")) ? HttpStatus.OK
                : "not_found".equals(result.get("status")) ? HttpStatus.NOT_FOUND : HttpStatus.BAD_REQUEST;
        return ResponseEntity.status(status).body(result);
    }

    private String firstNonBlank(String first, String second) {
        return first != null && !first.isBlank() ? first : second;
    }
}
