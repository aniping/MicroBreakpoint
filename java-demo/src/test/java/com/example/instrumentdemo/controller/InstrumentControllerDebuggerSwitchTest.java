package com.example.instrumentdemo.controller;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import com.example.instrumentdemo.debuger.DebuggerSettings;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "debugger.enabled=false"
})
class InstrumentControllerDebuggerSwitchTest {

    @Autowired
    private TestRestTemplate rest;

    @BeforeEach
    void setUp() {
        DebuggerSettings.enabled = false;
    }

    @AfterEach
    void tearDown() {
        DebuggerSettings.enabled = false;
    }

    @Test
    void debuggerSwitchEndpointTogglesEnabled() {
        ResponseEntity<Map<String, Object>> enabled = setDebuggerEnabled(true);

        assertThat(enabled.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(enabled.getBody()).containsEntry("success", true).containsEntry("enabled", true);
        assertThat(DebuggerSettings.enabled).isTrue();

        ResponseEntity<Map<String, Object>> disabled = setDebuggerEnabled(false);

        assertThat(disabled.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(disabled.getBody()).containsEntry("success", true).containsEntry("enabled", false);
        assertThat(DebuggerSettings.enabled).isFalse();
    }

    private ResponseEntity<Map<String, Object>> setDebuggerEnabled(boolean enabled) {
        return rest.exchange("/api/demo/debugger/enabled", HttpMethod.POST,
                new HttpEntity<>(Map.of("enabled", enabled)), new ParameterizedTypeReference<>() {
                });
    }
}
