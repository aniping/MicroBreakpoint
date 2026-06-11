package com.example.microbreakpoint.api;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
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
import org.springframework.web.multipart.MultipartFile;

import com.example.microbreakpoint.service.ArchiveService;
import com.example.microbreakpoint.service.DebugService;

@CrossOrigin
@RestController
@RequestMapping("/api/sessions")
public class SessionController {

    private final DebugService debugService;
    private final ArchiveService archiveService;

    public SessionController(DebugService debugService, ArchiveService archiveService) {
        this.debugService = debugService;
        this.archiveService = archiveService;
    }

    @GetMapping("")
    public Map<String, Object> sessions() {
        return Map.of("items", debugService.listSessions());
    }

    @PostMapping("")
    public Map<String, Object> create(@RequestBody(required = false) Map<String, Object> body) {
        return debugService.createSession(body == null ? Map.of() : body);
    }

    @PostMapping("/{sessionId}/select")
    public ResponseEntity<Map<String, Object>> select(@PathVariable String sessionId) {
        Map<String, Object> result = debugService.selectSession(sessionId);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 404).body(result);
    }

    @PostMapping("/{sessionId}/export")
    public ResponseEntity<Map<String, Object>> export(@PathVariable String sessionId,
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = archiveService.exportSessionArchive(sessionId, body == null ? Map.of() : body);
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 404).body(result);
    }

    @RequestMapping("/{sessionId}/export-file")
    public ResponseEntity<Resource> exportFile(@PathVariable String sessionId,
            @RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> result = archiveService.exportSessionArchiveFile(sessionId, body == null ? Map.of() : body);
        if (!Boolean.TRUE.equals(result.get("success"))) {
            return ResponseEntity.notFound().build();
        }
        String filename = String.valueOf(result.getOrDefault("archiveName", sessionId));
        if (!filename.toLowerCase().endsWith(".mbrec")) {
            filename += ".mbrec";
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.parseMediaType("application/zip"))
                .body(new FileSystemResource(Path.of(String.valueOf(result.get("path")))));
    }

    @PostMapping("/import")
    public ResponseEntity<Map<String, Object>> importSession(@RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> payload = body == null ? Map.of() : body;
        Object archive = payload.getOrDefault("archive", payload);
        Map<String, Object> result = archiveService.importSessionArchive(asMap(archive),
                truthy(payload.get("lockInterfaces")), stringValue(payload.get("importFileName")), null);
        int status = Boolean.TRUE.equals(result.get("success")) ? 200 : result.containsKey("existingSessionId") ? 409 : 400;
        return ResponseEntity.status(status).body(result);
    }

    @PostMapping("/import-file")
    public ResponseEntity<Map<String, Object>> importFile(@RequestParam(required = false) MultipartFile file,
            @RequestParam(required = false) String lockInterfaces,
            @RequestParam(required = false) String importFileName,
            HttpServletRequest request) throws IOException {
        Map<String, Object> result;
        if (file != null && !file.isEmpty()) {
            result = archiveService.importSessionArchiveFile(file, truthy(lockInterfaces));
        } else {
            result = archiveService.importSessionArchiveBytes(request.getInputStream().readAllBytes(),
                    truthy(lockInterfaces), importFileName);
        }
        int status = Boolean.TRUE.equals(result.get("success")) ? 200 : result.containsKey("existingSessionId") ? 409 : 400;
        return ResponseEntity.status(status).body(result);
    }

    @PostMapping("/current/clear")
    public ResponseEntity<Map<String, Object>> clearCurrent() {
        Map<String, Object> result = debugService.clearCurrentSession();
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 400).body(result);
    }

    @DeleteMapping("/{sessionId}")
    public ResponseEntity<Map<String, Object>> deleteOne(@PathVariable String sessionId) {
        Map<String, Object> result = debugService.deleteSession(sessionId);
        int status = Boolean.TRUE.equals(result.get("success")) ? 200
                : "session not found".equals(result.get("message")) ? 404 : 400;
        return ResponseEntity.status(status).body(result);
    }

    @DeleteMapping("")
    public ResponseEntity<Map<String, Object>> deleteAll() {
        Map<String, Object> result = debugService.clearSessions();
        return ResponseEntity.status(Boolean.TRUE.equals(result.get("success")) ? 200 : 400).body(result);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> asMap(Object value) {
        if (value instanceof Map<?, ?> map) {
            return (Map<String, Object>) map;
        }
        return Map.of();
    }

    private boolean truthy(Object value) {
        String text = String.valueOf(value == null ? "" : value);
        return "1".equals(text) || "true".equalsIgnoreCase(text) || "yes".equalsIgnoreCase(text);
    }

    private String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}
