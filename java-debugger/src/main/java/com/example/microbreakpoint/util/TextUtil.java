package com.example.microbreakpoint.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.Locale;

public final class TextUtil {

    private TextUtil() {
    }

    public static String nowIso() {
        return OffsetDateTime.now(ZoneOffset.UTC).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
    }

    public static String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    public static String safeSegment(Object value) {
        String text = String.valueOf(value == null ? "null" : value);
        String normalized = text.replaceAll("[^A-Za-z0-9._-]", "_");
        return normalized.isBlank() ? "unknown" : normalized;
    }

    public static String snakeCase(String value) {
        if (value == null) {
            return "";
        }
        StringBuilder result = new StringBuilder();
        for (char item : value.toCharArray()) {
            if (Character.isUpperCase(item)) {
                result.append('_').append(Character.toLowerCase(item));
            } else {
                result.append(item);
            }
        }
        return result.toString().toLowerCase(Locale.ROOT);
    }
}
