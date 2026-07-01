package com.example.microbreakpoint.service;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import com.example.microbreakpoint.config.DebuggerProperties;
import com.example.microbreakpoint.util.Jsons;
import com.example.microbreakpoint.util.TextUtil;

@Service
public class PayloadService {

    public static final int INLINE_LIMIT_BYTES = 64 * 1024;
    public static final int PREVIEW_LIMIT_BYTES = 8 * 1024;
    private static final int PREVIEW_STRING_CHARS = 180;
    private static final int PREVIEW_COLLECTION_ITEMS = 6;
    private static final int SUMMARY_LIMIT_CHARS = 200;

    private final JdbcTemplate jdbc;
    private final DebuggerProperties properties;

    public PayloadService(DatabaseService databaseService, DebuggerProperties properties) {
        this.jdbc = databaseService.jdbc();
        this.properties = properties;
    }

    public Path payloadRoot() {
        String configured = properties.getPayloadRoot();
        if (configured != null && !configured.isBlank()) {
            return Path.of(configured);
        }
        Path database = Path.of(properties.getDatabase()).toAbsolutePath();
        Path parent = database.getParent();
        return (parent == null ? Path.of("data") : parent).resolve("payloads");
    }

    public Map<String, Object> savePayload(String sessionId, String callId, String payloadType, Object value, String now) {
        Map<String, Object> meta = payloadMeta(value);
        String payloadId = "payload-" + TextUtil.sha256(sessionId + "|" + callId + "|" + payloadType).substring(0, 24);
        String storageType = ((Number) meta.get("size")).intValue() <= INLINE_LIMIT_BYTES ? "inline" : "file";
        String contentText = "inline".equals(storageType) ? (String) meta.get("content_text") : null;
        String contentPath = null;
        if ("file".equals(storageType)) {
            contentPath = payloadRelativePath(sessionId, callId, payloadType, (String) meta.get("content_format"));
            Path target = payloadRoot().resolve(contentPath);
            try {
                Files.createDirectories(target.getParent());
                Files.writeString(target, (String) meta.get("content_text"), StandardCharsets.UTF_8);
            } catch (IOException e) {
                throw new IllegalStateException("write payload failed", e);
            }
        }
        jdbc.update("""
                INSERT INTO call_payloads
                (id, call_id, session_id, payload_type, storage_type, content_text, content_path,
                 content_size, content_hash, content_encoding, content_format, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'utf-8', ?, ?)
                ON CONFLICT(call_id, payload_type) DO UPDATE SET
                  session_id=excluded.session_id,
                  storage_type=excluded.storage_type,
                  content_text=excluded.content_text,
                  content_path=excluded.content_path,
                  content_size=excluded.content_size,
                  content_hash=excluded.content_hash,
                  content_encoding=excluded.content_encoding,
                  content_format=excluded.content_format,
                  created_at=excluded.created_at
                """,
                payloadId, callId, sessionId, payloadType, storageType, contentText, contentPath,
                meta.get("size"), meta.get("hash"), meta.get("content_format"), now);
        meta.put("payload_id", payloadId);
        meta.put("storage_type", storageType);
        meta.put("content_path", contentPath);
        return meta;
    }

    public Map<String, Object> savePayloadFileCopy(String sessionId, String callId, String payloadType, String sourcePath,
            String contentFormat, String encoding, Number expectedSize, String expectedHash, String now) {
        Path source = Path.of(sourcePath);
        try {
            String text = Files.readString(source, StandardCharsets.UTF_8);
            String hash = TextUtil.sha256(text);
            int size = text.getBytes(StandardCharsets.UTF_8).length;
            if (expectedSize != null && expectedSize.longValue() != size) {
                throw new IllegalStateException("payload size mismatch");
            }
            if (expectedHash != null && !expectedHash.isBlank() && !expectedHash.equals(hash)) {
                throw new IllegalStateException("payload hash mismatch");
            }
            String payloadId = "payload-" + TextUtil.sha256(sessionId + "|" + callId + "|" + payloadType).substring(0, 24);
            String relativePath = payloadRelativePath(sessionId, callId, payloadType, contentFormat);
            Path target = payloadRoot().resolve(relativePath);
            Files.createDirectories(target.getParent());
            Files.copy(source, target, java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            jdbc.update("""
                    INSERT INTO call_payloads
                    (id, call_id, session_id, payload_type, storage_type, content_text, content_path,
                     content_size, content_hash, content_encoding, content_format, created_at)
                    VALUES (?, ?, ?, ?, 'file', NULL, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(call_id, payload_type) DO UPDATE SET
                      session_id=excluded.session_id,
                      storage_type=excluded.storage_type,
                      content_text=excluded.content_text,
                      content_path=excluded.content_path,
                      content_size=excluded.content_size,
                      content_hash=excluded.content_hash,
                      content_encoding=excluded.content_encoding,
                      content_format=excluded.content_format,
                      created_at=excluded.created_at
                    """,
                    payloadId, callId, sessionId, payloadType, relativePath, size, hash,
                    encoding == null || encoding.isBlank() ? "utf-8" : encoding,
                    contentFormat == null || contentFormat.isBlank() ? "json" : contentFormat, now);
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("payload_id", payloadId);
            result.put("size", size);
            result.put("hash", hash);
            return result;
        } catch (IOException e) {
            throw new IllegalStateException("copy payload failed", e);
        }
    }

    public Map<String, Object> payloadMeta(Object value) {
        String text = Jsons.dumps(value);
        byte[] data = text.getBytes(StandardCharsets.UTF_8);
        boolean truncated = data.length > PREVIEW_LIMIT_BYTES;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content_text", text);
        result.put("content_format", "json");
        result.put("summary", summarizePayload(value, text));
        result.put("preview", previewPayload(value, text, truncated, data.length));
        result.put("size", data.length);
        result.put("hash", TextUtil.sha256(text));
        result.put("truncated", truncated);
        return result;
    }

    public Map<String, Object> payloadChunk(String callId, String payloadType, Object offset, Object limit) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT * FROM call_payloads WHERE call_id=? AND payload_type=?", callId, payloadType);
        if (rows.isEmpty()) {
            return null;
        }
        return payloadChunkFromRow(rows.get(0), offset, limit, callId, payloadType, null);
    }

    public Map<String, Object> payloadChunkById(String payloadId, Object offset, Object limit) {
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT * FROM call_payloads WHERE id=?", payloadId);
        if (rows.isEmpty()) {
            return null;
        }
        Map<String, Object> row = rows.get(0);
        return payloadChunkFromRow(row, offset, limit, row.get("call_id"), row.get("payload_type"), payloadId);
    }

    public Map<String, Object> payloadChunkFromRow(Map<String, Object> row, Object offsetValue, Object limitValue,
            Object callId, Object payloadType, Object payloadId) {
        int offset = intValue(offsetValue, 0);
        int limit = Math.max(1, intValue(limitValue, PREVIEW_LIMIT_BYTES));
        int size = intValue(row.get("content_size"), 0);
        String content = readRange(row, offset, limit);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("success", true);
        result.put("callId", callId);
        result.put("payloadType", payloadType);
        result.put("payloadId", payloadId == null ? row.get("id") : payloadId);
        result.put("offset", offset);
        result.put("limit", limit);
        result.put("size", size);
        result.put("content", content);
        result.put("hasMore", offset + content.getBytes(StandardCharsets.UTF_8).length < size);
        result.put("contentFormat", row.get("content_format"));
        return result;
    }

    public Map<String, Object> exportPayloadTarget(String callId, String payloadType) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT * FROM call_payloads WHERE call_id=? AND payload_type=?", callId, payloadType);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public Map<String, Object> exportPayloadById(String payloadId) {
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT * FROM call_payloads WHERE id=?", payloadId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public Resource resourceFor(Map<String, Object> row) {
        try {
            if ("file".equals(row.get("storage_type"))) {
                return new InputStreamResource(Files.newInputStream(resolvePayloadPath((String) row.get("content_path"))));
            }
            InputStream stream = new java.io.ByteArrayInputStream(
                    String.valueOf(row.getOrDefault("content_text", "")).getBytes(StandardCharsets.UTF_8));
            return new InputStreamResource(stream);
        } catch (IOException e) {
            throw new IllegalStateException("open payload failed", e);
        }
    }

    public Map<String, Object> searchPayload(String callId, String payloadType, String query) {
        Map<String, Object> row = exportPayloadTarget(callId, payloadType);
        if (row == null) {
            return null;
        }
        return searchPayloadFromRow(row, query, callId, payloadType, row.get("id"));
    }

    public Map<String, Object> searchPayloadById(String payloadId, String query) {
        Map<String, Object> row = exportPayloadById(payloadId);
        if (row == null) {
            return null;
        }
        return searchPayloadFromRow(row, query, row.get("call_id"), row.get("payload_type"), payloadId);
    }

    public Map<String, Object> payloadFragment(Map<String, Object> payload) {
        String payloadRef = stringValue(firstNonNull(payload.get("payload_ref"), payload.get("payloadRef"),
                payload.get("payload_id"), payload.get("payloadId")));
        String fieldPath = stringValue(firstNonNull(payload.get("field_path"), payload.get("fieldPath")));
        if (payloadRef.isBlank() || fieldPath.isBlank()) {
            return payloadFragmentError("invalid_request", payloadRef, fieldPath, "payload_ref 和 field_path 不能为空。");
        }
        Map<String, Object> row = exportPayloadById(payloadRef);
        if (row == null) {
            return payloadFragmentError("not_found", payloadRef, fieldPath, "payload 不存在。");
        }
        Object root = Jsons.loads(readPayloadText(row), null);
        Map<String, Object> lookup = lookupPayloadFragment(root, fieldPath, stringValue(row.get("payload_type")));
        if (!Boolean.TRUE.equals(lookup.get("found"))) {
            return payloadFragmentError("not_found", payloadRef, fieldPath, "未找到指定 payload 字段。");
        }
        Map<String, Object> entity = new LinkedHashMap<>();
        entity.put("type", "payload_fragment");
        entity.put("id", payloadRef + "#" + fieldPath);
        entity.put("label", fieldPath);
        entity.put("status", "available");

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ok", true);
        result.put("status", "available");
        result.put("payload_ref", payloadRef);
        result.put("field_path", fieldPath);
        result.put("resolved_field_path", lookup.get("resolved_field_path"));
        result.put("value", lookup.get("value"));
        result.put("entities", List.of(entity));
        return result;
    }

    public Map<String, Object> searchPayloadFromRow(Map<String, Object> row, String query, Object callId,
            Object payloadType, Object payloadId) {
        String needle = query == null ? "" : query;
        List<Map<String, Object>> matches = new ArrayList<>();
        if (!needle.isBlank()) {
            String text = readPayloadText(row);
            int start = 0;
            while (matches.size() < 20) {
                int index = text.indexOf(needle, start);
                if (index < 0) {
                    break;
                }
                int previewStart = Math.max(0, index - 80);
                int previewEnd = Math.min(text.length(), index + needle.length() + 80);
                Map<String, Object> match = new LinkedHashMap<>();
                match.put("offset", text.substring(0, index).getBytes(StandardCharsets.UTF_8).length);
                match.put("preview", text.substring(previewStart, previewEnd));
                matches.add(match);
                start = index + Math.max(1, needle.length());
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("success", true);
        result.put("callId", callId);
        result.put("payloadType", payloadType);
        result.put("payloadId", payloadId);
        result.put("query", needle);
        result.put("matches", matches);
        return result;
    }

    private Map<String, Object> lookupPayloadFragment(Object root, String fieldPath, String payloadType) {
        for (String candidate : fieldPathCandidates(fieldPath, payloadType)) {
            Map<String, Object> found = lookupField(root, fieldSegments(candidate));
            if (Boolean.TRUE.equals(found.get("found"))) {
                found.put("resolved_field_path", candidate);
                return found;
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("found", false);
        return result;
    }

    private List<String> fieldPathCandidates(String fieldPath, String payloadType) {
        String path = stringValue(fieldPath).trim();
        List<String> candidates = new ArrayList<>();
        addCandidate(candidates, path);
        for (String prefix : List.of("request.", "response.")) {
            if (path.startsWith(prefix)) {
                addCandidate(candidates, path.substring(prefix.length()));
            }
        }
        if ("params".equals(payloadType)) {
            for (String prefix : List.of("request.parameters.", "request.params.", "parameters.", "params.")) {
                if (path.startsWith(prefix)) {
                    addCandidate(candidates, path.substring(prefix.length()));
                }
            }
        }
        if ("result".equals(payloadType)) {
            for (String prefix : List.of("response.result.", "result.")) {
                if (path.startsWith(prefix)) {
                    addCandidate(candidates, path.substring(prefix.length()));
                }
            }
        }
        return candidates;
    }

    private void addCandidate(List<String> candidates, String value) {
        String candidate = stringValue(value).replaceAll("^[.\\s]+|[.\\s]+$", "");
        if (!candidates.contains(candidate)) {
            candidates.add(candidate);
        }
    }

    private List<String> fieldSegments(String path) {
        List<String> segments = new ArrayList<>();
        for (String part : stringValue(path).split("\\.")) {
            String rest = part.trim();
            while (!rest.isBlank()) {
                int bracket = rest.indexOf('[');
                if (bracket < 0) {
                    segments.add(cleanSegment(rest));
                    break;
                }
                if (bracket > 0) {
                    segments.add(cleanSegment(rest.substring(0, bracket)));
                }
                int close = rest.indexOf(']', bracket);
                if (close < 0) {
                    segments.add(cleanSegment(rest.substring(bracket + 1)));
                    break;
                }
                segments.add(cleanSegment(rest.substring(bracket + 1, close)));
                rest = rest.substring(close + 1).trim();
            }
        }
        return segments.stream().filter(segment -> !segment.isBlank()).toList();
    }

    private String cleanSegment(String value) {
        String segment = stringValue(value).trim();
        if (segment.length() >= 2 && (segment.charAt(0) == '\'' || segment.charAt(0) == '"')
                && segment.charAt(segment.length() - 1) == segment.charAt(0)) {
            return segment.substring(1, segment.length() - 1);
        }
        return segment;
    }

    private Map<String, Object> lookupField(Object root, List<String> segments) {
        Object current = root;
        for (String segment : segments) {
            if (current instanceof Map<?, ?> map) {
                if (!map.containsKey(segment)) {
                    return Map.of("found", false);
                }
                current = map.get(segment);
            } else if (current instanceof List<?> list) {
                try {
                    current = list.get(Integer.parseInt(segment));
                } catch (RuntimeException e) {
                    return Map.of("found", false);
                }
            } else {
                return Map.of("found", false);
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("found", true);
        result.put("value", current);
        return result;
    }

    private Map<String, Object> payloadFragmentError(String status, String payloadRef, String fieldPath, String message) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ok", false);
        result.put("status", status);
        result.put("payload_ref", payloadRef);
        result.put("field_path", fieldPath);
        result.put("message", message);
        result.put("entities", List.of());
        return result;
    }

    public String readPayloadText(Map<String, Object> row) {
        if ("file".equals(row.get("storage_type"))) {
            try {
                return Files.readString(resolvePayloadPath((String) row.get("content_path")), StandardCharsets.UTF_8);
            } catch (IOException e) {
                throw new IllegalStateException("read payload failed", e);
            }
        }
        Object text = row.get("content_text");
        return text == null ? "" : String.valueOf(text);
    }

    public Path resolvePayloadPath(String contentPath) {
        Path path = Path.of(contentPath);
        return path.isAbsolute() ? path : payloadRoot().resolve(path);
    }

    public String payloadIdFor(String sessionId, String callId, String payloadType) {
        return "payload-" + TextUtil.sha256(sessionId + "|" + callId + "|" + payloadType).substring(0, 24);
    }

    public String relativePathFor(String sessionId, String callId, String payloadType, String contentFormat) {
        return payloadRelativePath(sessionId, callId, payloadType, contentFormat);
    }

    private String readRange(Map<String, Object> row, int offset, int limit) {
        String text = readPayloadText(row);
        if (offset <= 0) {
            return truncateUtf8(text, limit);
        }
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (offset >= bytes.length) {
            return "";
        }
        int end = Math.min(bytes.length, offset + limit);
        return new String(bytes, offset, end - offset, StandardCharsets.UTF_8);
    }

    private String previewPayload(Object value, String serializedText, boolean truncated, int contentSize) {
        if (!truncated) {
            return serializedText;
        }
        for (int stringLimit : List.of(PREVIEW_STRING_CHARS, 120, 60)) {
            for (int itemLimit : List.of(PREVIEW_COLLECTION_ITEMS, 4, 2)) {
                String text = Jsons.dumps(previewJsonValue(value, stringLimit, itemLimit, 0));
                if (text.getBytes(StandardCharsets.UTF_8).length <= PREVIEW_LIMIT_BYTES) {
                    return text;
                }
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("__preview__", "payload truncated");
        result.put("contentSize", contentSize);
        result.put("message", "Full payload is available via load more or export.");
        return Jsons.dumps(result);
    }

    private Object previewJsonValue(Object value, int stringLimit, int itemLimit, int depth) {
        if (depth >= 6) {
            return previewMarker(value);
        }
        if (value instanceof String text) {
            return text.length() <= stringLimit ? text : text.substring(0, stringLimit) + "…";
        }
        if (value instanceof List<?> list) {
            List<Object> result = new ArrayList<>();
            for (int index = 0; index < Math.min(itemLimit, list.size()); index++) {
                result.add(previewJsonValue(list.get(index), stringLimit, itemLimit, depth + 1));
            }
            if (list.size() > itemLimit) {
                Map<String, Object> marker = new LinkedHashMap<>();
                marker.put("__preview__", "items truncated");
                marker.put("omittedItems", list.size() - itemLimit);
                result.add(marker);
            }
            return result;
        }
        if (value instanceof Map<?, ?> map) {
            Map<String, Object> result = new LinkedHashMap<>();
            List<String> keys = map.keySet().stream().map(String::valueOf).toList();
            for (int index = 0; index < Math.min(itemLimit, keys.size()); index++) {
                String key = keys.get(index);
                String previewKey = previewJsonKey(key, stringLimit);
                if (result.containsKey(previewKey)) {
                    previewKey = previewKey + " #" + (index + 1);
                }
                result.put(previewKey, previewJsonValue(map.get(key), stringLimit, itemLimit, depth + 1));
            }
            if (keys.size() > itemLimit) {
                Map<String, Object> marker = new LinkedHashMap<>();
                marker.put("keyCount", keys.size());
                marker.put("shownKeys", itemLimit);
                marker.put("omittedKeys", keys.size() - itemLimit);
                result.put("__preview__", marker);
            }
            return result;
        }
        return value;
    }

    private String previewJsonKey(String key, int stringLimit) {
        int limit = Math.max(24, Math.min(stringLimit, 120));
        return key.length() <= limit ? key : key.substring(0, limit) + "... [key truncated " + (key.length() - limit) + " chars]";
    }

    private Object previewMarker(Object value) {
        if (value instanceof Map<?, ?> map) {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("__preview__", "object truncated");
            result.put("keyCount", map.size());
            return result;
        }
        if (value instanceof List<?> list) {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("__preview__", "array truncated");
            result.put("itemCount", list.size());
            return result;
        }
        if (value instanceof String text) {
            return text.length() > 80 ? text.substring(0, 80) + "..." : text;
        }
        return value;
    }

    private String summarizePayload(Object value, String serializedText) {
        String text;
        if (value == null) {
            text = "null";
        } else if (value instanceof Map<?, ?> map) {
            List<String> keys = map.keySet().stream().map(String::valueOf).sorted(Comparator.naturalOrder()).toList();
            List<String> parts = new ArrayList<>();
            for (String key : keys.subList(0, Math.min(8, keys.size()))) {
                parts.add(key + "=" + summaryValue(map.get(key)));
            }
            if (keys.size() > 8) {
                parts.add("...");
            }
            text = parts.isEmpty() ? "{}" : String.join(", ", parts);
        } else if (value instanceof List<?> list) {
            text = "Array(" + list.size() + ")";
        } else {
            text = String.valueOf(value);
        }
        if (text.isBlank()) {
            text = serializedText.replace("\n", " ");
        }
        text = text.replaceAll("\\s+", " ").trim();
        return text.length() > SUMMARY_LIMIT_CHARS ? text.substring(0, SUMMARY_LIMIT_CHARS - 3) + "..." : text;
    }

    private String summaryValue(Object value) {
        if (value instanceof List<?> list) {
            return "Array(" + list.size() + ")";
        }
        if (value instanceof Map<?, ?> map) {
            return "Object(" + map.size() + ")";
        }
        String text = String.valueOf(value);
        return text.length() > 40 ? text.substring(0, 37) + "..." : text;
    }

    private String payloadRelativePath(String sessionId, String callId, String payloadType, String contentFormat) {
        String suffix = "json".equals(contentFormat) ? "json" : "txt";
        return TextUtil.safeSegment(sessionId) + "/" + TextUtil.sha256(callId).substring(0, 2) + "/"
                + TextUtil.safeSegment(callId) + "/" + payloadType + "." + suffix;
    }

    private String truncateUtf8(String text, int limit) {
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (bytes.length <= limit) {
            return text;
        }
        return new String(bytes, 0, limit, StandardCharsets.UTF_8);
    }

    private Object firstNonNull(Object... values) {
        for (Object value : values) {
            if (value != null) {
                return value;
            }
        }
        return null;
    }

    private String stringValue(Object value) {
        return value == null ? "" : String.valueOf(value);
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
}
