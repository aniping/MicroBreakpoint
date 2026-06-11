package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.service.DebugService;

@CrossOrigin
@RestController
@RequestMapping("/api/debug")
public class DebugController {

    private final DebugService debugService;

    public DebugController(DebugService debugService) {
        this.debugService = debugService;
    }

    @GetMapping("/state")
    public Map<String, Object> state() {
        return debugService.stateResponse();
    }

    @PostMapping("/start")
    public ResponseEntity<Map<String, Object>> start(@RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = debugService.startDebug(body == null ? Map.of() : body);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 400).body(result);
    }

    @PostMapping("/stop")
    public Map<String, Object> stop() {
        int released = debugService.stopDebug();
        return debugService.stateResponse(DebugService.mapOf("success", true, "releasedCount", released));
    }

    @PostMapping("/reset")
    public Map<String, Object> reset() {
        return debugService.resetDebug();
    }
}
