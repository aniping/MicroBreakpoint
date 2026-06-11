package com.example.microbreakpoint.util;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;

public final class Jsons {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);

    private Jsons() {
    }

    public static String dumps(Object value) {
        try {
            return MAPPER.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            return String.valueOf(value);
        }
    }

    public static Object loads(String value, Object defaultValue) {
        if (value == null || value.isBlank()) {
            return defaultValue;
        }
        try {
            return MAPPER.readValue(value, Object.class);
        } catch (JsonProcessingException e) {
            return defaultValue;
        }
    }

    public static Map<String, Object> object(Object value) {
        if (value instanceof Map<?, ?> input) {
            Map<String, Object> result = new LinkedHashMap<>();
            input.forEach((key, item) -> result.put(String.valueOf(key), item));
            return result;
        }
        return new LinkedHashMap<>();
    }

    public static List<Object> list(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        try {
            return MAPPER.readValue(value, new TypeReference<>() {
            });
        } catch (JsonProcessingException e) {
            return List.of();
        }
    }
}
