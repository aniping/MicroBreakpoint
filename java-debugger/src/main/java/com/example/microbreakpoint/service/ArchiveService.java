package com.example.microbreakpoint.service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.example.microbreakpoint.util.Jsons;
import com.example.microbreakpoint.util.TextUtil;

@Service
public class ArchiveService {

    private static final String MBREC_FORMAT = "MicroBreakpoint Session Archive";
    private static final int MBREC_VERSION = 1;

    private final JdbcTemplate jdbc;
    private final DebugService debugService;
    private final PayloadService payloadService;

    public ArchiveService(DatabaseService databaseService, DebugService debugService, PayloadService payloadService) {
        this.jdbc = databaseService.jdbc();
        this.debugService = debugService;
        this.payloadService = payloadService;
    }

    public synchronized Map<String, Object> exportSessionArchive(String sessionId, Map<String, Object> payload) {
        Map<String, Object> session = first("SELECT * FROM debug_session WHERE id=?", sessionId);
        if (session == null) {
            return DebugService.mapOf("success", false, "message", "session not found");
        }
        String archiveId = str(session.get("archive_id")).trim();
        String now = TextUtil.nowIso();
        if (archiveId.isBlank()) {
            archiveId = "mbrec-" + UUID.randomUUID().toString().replace("-", "");
        }
        String archiveName = str(firstNonNull(payload.get("archiveName"), session.get("display_name"),
                session.get("archive_name"), sessionId, "session")).trim();
        if (archiveName.isBlank()) {
            archiveName = "session";
        }
        String remark = str(firstNonNull(payload.get("remark"), ""));
        String displayName = stripMbrecSuffix(archiveName);
        jdbc.update("""
                UPDATE debug_session
                SET archive_id=?, archive_name=?, archive_remark=?, display_name=COALESCE(?, display_name), updated_at=?
                WHERE id=?
                """, archiveId, archiveName, remark, displayName.isBlank() ? null : displayName, now, sessionId);
        session = first("SELECT * FROM debug_session WHERE id=?", sessionId);
        Map<String, Object> archive = new LinkedHashMap<>();
        archive.put("format", MBREC_FORMAT);
        archive.put("extension", ".mbrec");
        archive.put("version", MBREC_VERSION);
        archive.put("archiveId", archiveId);
        archive.put("archiveName", archiveName);
        archive.put("remark", remark);
        archive.put("exportedAt", now);
        archive.put("sourceSessionId", sessionId);
        archive.put("session", session);
        archive.put("calls", rows("SELECT * FROM call_record WHERE session_id=? ORDER BY call_index ASC, id ASC", sessionId));
        archive.put("callPayloads", archivePayloadRows(sessionId));
        archive.put("interfaces",
                rows("SELECT * FROM discovered_interface WHERE session_id=? ORDER BY first_seen_at ASC", sessionId));
        archive.put("interfaceParamSamples", rows("""
                SELECT s.* FROM interface_param_sample s
                JOIN discovered_interface i ON s.interface_id=i.id
                WHERE i.session_id=?
                ORDER BY s.first_seen_at ASC
                """, sessionId));
        archive.put("breakpoints",
                rows("SELECT * FROM breakpoint WHERE session_id=? ORDER BY created_at ASC", sessionId));
        return DebugService.mapOf("success", true, "archive", archive);
    }

    public synchronized Map<String, Object> exportSessionArchiveFile(String sessionId, Map<String, Object> payload) {
        Map<String, Object> result = exportSessionArchive(sessionId, payload);
        if (!Boolean.TRUE.equals(result.get("success"))) {
            return result;
        }
        Map<String, Object> archive = object(result.get("archive"));
        try {
            Path target = Files.createTempFile("micro-breakpoint-", ".mbrec");
            try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(target), StandardCharsets.UTF_8)) {
                writeZipText(zip, "manifest.json", Jsons.dumps(DebugService.mapOf(
                        "format", MBREC_FORMAT,
                        "version", MBREC_VERSION,
                        "archiveId", archive.get("archiveId"),
                        "archiveName", archive.get("archiveName"),
                        "exportedAt", archive.get("exportedAt"),
                        "content", "zip")));
                writeZipText(zip, "db.json", Jsons.dumps(archive));
                for (Map<String, Object> row : rows(
                        "SELECT * FROM call_payloads WHERE session_id=? AND storage_type='file' ORDER BY created_at ASC",
                        sessionId)) {
                    String entry = payloadZipEntry(row);
                    Path source = payloadService.resolvePayloadPath(str(row.get("content_path")));
                    if (Files.exists(source)) {
                        zip.putNextEntry(new ZipEntry(entry));
                        Files.copy(source, zip);
                        zip.closeEntry();
                    }
                }
            }
            return DebugService.mapOf("success", true, "path", target.toString(), "archiveId", archive.get("archiveId"),
                    "archiveName", archive.get("archiveName"));
        } catch (IOException e) {
            return DebugService.mapOf("success", false, "message", e.getMessage());
        }
    }

    public synchronized Map<String, Object> importSessionArchive(Map<String, Object> archive, boolean lockInterfaces,
            String importFileName, Map<String, byte[]> payloadEntries) {
        if (archive == null || !MBREC_FORMAT.equals(archive.get("format"))
                || intValue(archive.get("version"), 0) != MBREC_VERSION) {
            return DebugService.mapOf("success", false, "message", "unsupported archive");
        }
        String archiveId = str(archive.get("archiveId"));
        if (archiveId.isBlank()) {
            return DebugService.mapOf("success", false, "message", "archiveId missing");
        }
        Map<String, Object> existing = first("SELECT id FROM debug_session WHERE archive_id=?", archiveId);
        if (existing != null) {
            String archiveName = str(firstNonNull(archive.get("archiveName"), object(archive.get("session")).get("archive_name"),
                    archiveId));
            return DebugService.mapOf(
                    "success", false,
                    "message", "archive already imported",
                    "archiveId", archiveId,
                    "archiveName", archiveName,
                    "importFileName", cleanImportFileName(importFileName),
                    "existingSessionId", existing.get("id"),
                    "openExisting", true);
        }

        debugService.stopDebug();
        String now = TextUtil.nowIso();
        String newSessionId = "session-" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
        Map<String, Object> source = object(archive.get("session"));
        String archiveName = str(firstNonNull(archive.get("archiveName"), ""));
        String archiveRemark = str(firstNonNull(archive.get("remark"), ""));
        String cleanImportName = cleanImportFileName(importFileName);
        String displayName = importedDisplayName(cleanImportName, archiveName);

        Map<String, String> interfaceIds = new HashMap<>();
        for (Map<String, Object> item : list(archive.get("interfaces"))) {
            String oldId = str(item.get("id"));
            String newId = UUID.nameUUIDFromBytes((newSessionId + "|" + item.get("object_name") + "|"
                    + item.get("cmd_name")).getBytes(StandardCharsets.UTF_8)).toString().replace("-", "");
            interfaceIds.put(oldId, newId);
        }
        Map<String, String> callIds = new HashMap<>();
        for (Map<String, Object> item : list(archive.get("calls"))) {
            callIds.put(str(item.get("call_id")), "call-" + UUID.randomUUID().toString().replace("-", "").substring(0, 12));
        }
        Map<String, String> breakpointIds = new HashMap<>();
        for (Map<String, Object> item : list(archive.get("breakpoints"))) {
            breakpointIds.put(str(item.get("id")), "bp-" + UUID.randomUUID().toString().replace("-", "").substring(0, 10));
        }

        jdbc.update("""
                INSERT INTO debug_session
                (id, mode, status, service_name, operator, start_time, end_time, recording, debugging, remark,
                 display_name, import_file_name, archive_id, archive_name, archive_remark, imported_at, created_at, updated_at)
                VALUES (?, 'idle', 'idle', ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                newSessionId,
                firstNonNull(source.get("service_name"), "instrument-service-demo"),
                firstNonNull(source.get("operator"), "developer"),
                firstNonNull(source.get("start_time"), source.get("created_at"), now),
                source.get("end_time"),
                firstNonNull(archiveRemark, source.get("remark"), ""),
                displayName,
                cleanImportName,
                archiveId,
                archiveName,
                archiveRemark,
                now,
                now,
                now);

        for (Map<String, Object> item : list(archive.get("interfaces"))) {
            String oldId = str(item.get("id"));
            Map<String, Object> row = new LinkedHashMap<>(item);
            row.put("id", interfaceIds.get(oldId));
            row.put("session_id", newSessionId);
            row.put("created_at", now);
            row.put("updated_at", now);
            insertArchiveRow("discovered_interface", row);
        }
        for (Map<String, Object> item : list(archive.get("breakpoints"))) {
            String oldId = str(item.get("id"));
            Map<String, Object> row = new LinkedHashMap<>(item);
            row.put("id", breakpointIds.get(oldId));
            row.put("session_id", newSessionId);
            row.put("source_session_id", newSessionId);
            row.put("source_interface_id", mapValue(interfaceIds, row.get("source_interface_id")));
            row.put("source_call_id", mapValue(callIds, row.get("source_call_id")));
            row.put("created_at", now);
            row.put("updated_at", now);
            insertArchiveRow("breakpoint", row);
        }
        for (Map<String, Object> item : list(archive.get("calls"))) {
            Map<String, Object> row = new LinkedHashMap<>(item);
            row.remove("id");
            row.put("call_id", mapValue(callIds, item.get("call_id")));
            row.put("session_id", newSessionId);
            row.put("interface_id", mapValue(interfaceIds, item.get("interface_id")));
            row.put("breakpoint_id", mapValue(breakpointIds, item.get("breakpoint_id")));
            if ("paused".equals(row.get("status"))) {
                row.put("status", "imported_paused");
                row.put("continued_at", null);
            }
            row.put("created_at", now);
            row.put("updated_at", now);
            insertArchiveRow("call_record", row);
        }
        for (Map<String, Object> item : list(archive.get("interfaceParamSamples"))) {
            Map<String, Object> row = new LinkedHashMap<>(item);
            row.put("id", UUID.randomUUID().toString().replace("-", ""));
            row.put("interface_id", mapValue(interfaceIds, item.get("interface_id")));
            row.put("call_id", mapValue(callIds, item.get("call_id")));
            row.put("created_at", now);
            row.put("updated_at", now);
            insertArchiveRow("interface_param_sample", row);
        }
        for (Map<String, Object> item : list(archive.get("callPayloads"))) {
            importPayloadRow(item, newSessionId, callIds, payloadEntries, now);
        }
        if (lockInterfaces) {
            debugService.setInterfaceLocked(true);
        }
        debugService.selectSession(newSessionId);
        return DebugService.mapOf("success", true, "importedSessionId", newSessionId, "sessionId", newSessionId,
                "debugging", false, "interfaceLocked", lockInterfaces);
    }

    public Map<String, Object> importSessionArchiveFile(MultipartFile upload, boolean lockInterfaces) {
        try {
            Map<String, byte[]> entries = readZipEntries(upload.getInputStream());
            byte[] dbJson = entries.get("db.json");
            if (dbJson == null) {
                return DebugService.mapOf("success", false, "message", "db.json missing");
            }
            Map<String, Object> archive = object(Jsons.loads(new String(dbJson, StandardCharsets.UTF_8), null));
            return importSessionArchive(archive, lockInterfaces, upload.getOriginalFilename(), entries);
        } catch (IOException e) {
            return DebugService.mapOf("success", false, "message", e.getMessage());
        }
    }

    public Map<String, Object> importSessionArchiveBytes(byte[] bytes, boolean lockInterfaces, String importFileName) {
        try {
            Map<String, byte[]> entries = readZipEntries(new ByteArrayInputStream(bytes));
            byte[] dbJson = entries.get("db.json");
            if (dbJson == null) {
                return DebugService.mapOf("success", false, "message", "db.json missing");
            }
            Map<String, Object> archive = object(Jsons.loads(new String(dbJson, StandardCharsets.UTF_8), null));
            return importSessionArchive(archive, lockInterfaces, importFileName, entries);
        } catch (IOException e) {
            return DebugService.mapOf("success", false, "message", e.getMessage());
        }
    }

    private void importPayloadRow(Map<String, Object> item, String newSessionId, Map<String, String> callIds,
            Map<String, byte[]> payloadEntries, String now) {
        String payloadType = str(firstNonNull(item.get("payload_type"), "params"));
        String newCallId = mapValue(callIds, item.get("call_id"));
        if (newCallId == null || newCallId.isBlank()) {
            return;
        }
        String contentFormat = str(firstNonNull(item.get("content_format"), "json"));
        String payloadId = payloadService.payloadIdFor(newSessionId, newCallId, payloadType);
        String storageType = str(firstNonNull(item.get("storage_type"), "inline"));
        String contentText = null;
        String contentPath = null;
        if ("file".equals(storageType)) {
            String entry = str(item.get("export_entry"));
            byte[] content = payloadEntries == null ? null : payloadEntries.get(entry);
            if (content == null) {
                return;
            }
            contentPath = payloadService.relativePathFor(newSessionId, newCallId, payloadType, contentFormat);
            try {
                Path target = payloadService.payloadRoot().resolve(contentPath);
                Files.createDirectories(target.getParent());
                Files.write(target, content);
            } catch (IOException e) {
                throw new IllegalStateException("restore payload failed", e);
            }
        } else {
            contentText = str(firstNonNull(item.get("export_content_text"), item.get("content_text"), ""));
        }
        jdbc.update("""
                INSERT INTO call_payloads
                (id, call_id, session_id, payload_type, storage_type, content_text, content_path,
                 content_size, content_hash, content_encoding, content_format, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                payloadId, newCallId, newSessionId, payloadType, storageType, contentText, contentPath,
                item.get("content_size"), item.get("content_hash"),
                firstNonNull(item.get("content_encoding"), "utf-8"), contentFormat, now);
    }

    private List<Map<String, Object>> archivePayloadRows(String sessionId) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rows("SELECT * FROM call_payloads WHERE session_id=? ORDER BY created_at ASC",
                sessionId)) {
            Map<String, Object> item = new LinkedHashMap<>(row);
            if ("inline".equals(row.get("storage_type"))) {
                item.put("export_content_text", firstNonNull(row.get("content_text"), ""));
            } else {
                item.put("export_entry", payloadZipEntry(row));
            }
            result.add(item);
        }
        return result;
    }

    private String payloadZipEntry(Map<String, Object> row) {
        String contentPath = str(row.get("content_path")).replace("\\", "/").replaceFirst("^/+", "");
        if (!contentPath.isBlank()) {
            return "payloads/" + contentPath;
        }
        String suffix = "json".equals(firstNonNull(row.get("content_format"), "json")) ? "json" : "txt";
        return "payloads/" + row.getOrDefault("session_id", "unknown") + "/" + row.getOrDefault("call_id", "unknown")
                + "/" + row.getOrDefault("payload_type", "params") + "." + suffix;
    }

    private void insertArchiveRow(String table, Map<String, Object> row) {
        List<String> columns = rows("PRAGMA table_info(" + table + ")").stream()
                .map(item -> str(item.get("name"))).filter(name -> row.containsKey(name)).toList();
        String placeholders = String.join(",", columns.stream().map(ignored -> "?").toList());
        String sql = "INSERT INTO " + table + " (" + String.join(",", columns) + ") VALUES (" + placeholders + ")";
        Object[] args = columns.stream().map(row::get).toArray();
        jdbc.update(sql, args);
    }

    private Map<String, byte[]> readZipEntries(InputStream input) throws IOException {
        Map<String, byte[]> result = new HashMap<>();
        try (ZipInputStream zip = new ZipInputStream(input, StandardCharsets.UTF_8)) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                if (!entry.isDirectory()) {
                    result.put(entry.getName(), zip.readAllBytes());
                }
                zip.closeEntry();
            }
        }
        return result;
    }

    private void writeZipText(ZipOutputStream zip, String name, String text) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(text.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }

    private List<Map<String, Object>> rows(String sql, Object... args) {
        return jdbc.queryForList(sql, args);
    }

    private Map<String, Object> first(String sql, Object... args) {
        List<Map<String, Object>> rows = rows(sql, args);
        return rows.isEmpty() ? null : rows.get(0);
    }

    private String mapValue(Map<String, String> mapping, Object oldValue) {
        if (oldValue == null || str(oldValue).isBlank()) {
            return null;
        }
        return mapping.get(str(oldValue));
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> list(Object value) {
        if (value instanceof List<?> items) {
            List<Map<String, Object>> result = new ArrayList<>();
            for (Object item : items) {
                result.add(object(item));
            }
            return result;
        }
        return List.of();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> object(Object value) {
        if (value instanceof Map<?, ?> map) {
            Map<String, Object> result = new LinkedHashMap<>();
            map.forEach((key, item) -> result.put(String.valueOf(key), item));
            return result;
        }
        return new LinkedHashMap<>();
    }

    private String importedDisplayName(String importFileName, String archiveName) {
        String name = !str(importFileName).isBlank() ? importFileName : archiveName;
        name = stripMbrecSuffix(name);
        return name.isBlank() ? "导入会话" : name;
    }

    private String stripMbrecSuffix(String value) {
        String text = str(value).trim();
        return text.toLowerCase().endsWith(".mbrec") ? text.substring(0, text.length() - 6) : text;
    }

    private String cleanImportFileName(String value) {
        String text = str(value).trim();
        return text.isBlank() ? null : text;
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private int intValue(Object value, int defaultValue) {
        if (value instanceof Number number) {
            return number.intValue();
        }
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (Exception e) {
            return defaultValue;
        }
    }

    private String str(Object value) {
        return value == null ? "" : String.valueOf(value);
    }
}
