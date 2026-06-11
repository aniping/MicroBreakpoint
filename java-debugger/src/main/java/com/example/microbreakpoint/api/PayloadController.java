package com.example.microbreakpoint.api;

import java.util.Map;

import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.microbreakpoint.service.PayloadService;

@CrossOrigin
@RestController
@RequestMapping("/api/payloads")
public class PayloadController {

    private final PayloadService payloadService;

    public PayloadController(PayloadService payloadService) {
        this.payloadService = payloadService;
    }

    @GetMapping("/{payloadId}")
    public ResponseEntity<Map<String, Object>> payload(@PathVariable String payloadId,
            @RequestParam(defaultValue = "0") String offset,
            @RequestParam(defaultValue = "1048576") String limit) {
        Map<String, Object> result = payloadService.payloadChunkById(payloadId, offset, limit);
        return result == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "payload not found"))
                : ResponseEntity.ok(result);
    }

    @GetMapping("/{payloadId}/export")
    public ResponseEntity<Resource> export(@PathVariable String payloadId) {
        Map<String, Object> row = payloadService.exportPayloadById(payloadId);
        if (row == null) {
            return ResponseEntity.notFound().build();
        }
        String payloadType = String.valueOf(row.getOrDefault("payload_type", "payload"));
        String filename = "json".equals(row.getOrDefault("content_format", "json")) ? payloadType + ".json"
                : payloadType + ".txt";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + filename)
                .contentType(filename.endsWith(".json") ? MediaType.APPLICATION_JSON : MediaType.TEXT_PLAIN)
                .body(payloadService.resourceFor(row));
    }

    @GetMapping("/{payloadId}/search")
    public ResponseEntity<Map<String, Object>> search(@PathVariable String payloadId,
            @RequestParam(defaultValue = "") String q) {
        Map<String, Object> result = payloadService.searchPayloadById(payloadId, q);
        return result == null
                ? ResponseEntity.status(404).body(Map.of("success", false, "message", "payload not found"))
                : ResponseEntity.ok(result);
    }
}
