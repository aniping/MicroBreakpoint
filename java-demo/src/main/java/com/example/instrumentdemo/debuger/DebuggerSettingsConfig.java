package com.example.instrumentdemo.debuger;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DebuggerSettingsConfig {

    public DebuggerSettingsConfig(
            @Value("${debugger.enabled:true}") boolean enabled,
            @Value("${debugger.server-url:http://127.0.0.1:18601}") String serverUrl,
            @Value("${debugger.service-name:instrument-service}") String serviceName,
            @Value("${debugger.connect-timeout-ms:300}") int connectTimeoutMs,
            @Value("${debugger.read-timeout-ms:1000}") int readTimeoutMs,
            @Value("${debugger.breakpoint-timeout-ms:300000}") int breakpointTimeoutMs) {
        DebuggerSettings.enabled = enabled;
        DebuggerSettings.serverUrl = serverUrl;
        DebuggerSettings.serviceName = serviceName;
        DebuggerSettings.connectTimeoutMs = connectTimeoutMs;
        DebuggerSettings.readTimeoutMs = readTimeoutMs;
        DebuggerSettings.breakpointTimeoutMs = breakpointTimeoutMs;
    }
}
