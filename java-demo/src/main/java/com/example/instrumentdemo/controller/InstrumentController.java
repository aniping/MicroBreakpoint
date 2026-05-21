package com.example.instrumentdemo.controller;

import com.example.instrumentdemo.model.ValueResult;
import com.example.instrumentdemo.service.InstrumentService;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/demo")
public class InstrumentController {
    private static final Logger log = LoggerFactory.getLogger(InstrumentController.class);
    private final InstrumentService instrumentService;

    public InstrumentController(InstrumentService instrumentService) {
        this.instrumentService = instrumentService;
    }

    @GetMapping("/ping")
    public String ping() {
        return "pong";
    }

    @GetMapping("/initialize")
    public ValueResult initialize() {
        log.info("[MicroBreakpoint] REST /api/demo/initialize received");
        return instrumentService.instrumentInitialize("VNA", "1", Map.of("source", "demo"));
    }

    @GetMapping("/control")
    public ValueResult control(
            @RequestParam(defaultValue = "VNA") String instType,
            @RequestParam(defaultValue = "create") String cmdName,
            @RequestParam(defaultValue = "1") int slotId) {
        log.info("[MicroBreakpoint] REST /api/demo/control received instType={} cmdName={} slotId={}",
                instType, cmdName, slotId);
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("source", "demo");
        params.put("requestedBy", "rest-controller");
        return instrumentService.instrumentControl(instType, cmdName, slotId, params);
    }

    @GetMapping("/error")
    public ValueResult error() {
        log.info("[MicroBreakpoint] REST /api/demo/error received");
        return instrumentService.instrumentControl("VNA", "error", 1, Map.of("source", "demo"));
    }
}
