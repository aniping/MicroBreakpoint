package com.example.microbreakpoint.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "micro-breakpoint")
public class DebuggerProperties {

    private String database = "../python-debugger/data/debugger.sqlite3";
    private String payloadRoot;
    private int breakpointTimeoutSeconds = 300;
    private String demoBaseUrl = "http://127.0.0.1:8080";
    private int demoRequestTimeoutMs = 1000;

    public String getDatabase() {
        return database;
    }

    public void setDatabase(String database) {
        this.database = database;
    }

    public String getPayloadRoot() {
        return payloadRoot;
    }

    public void setPayloadRoot(String payloadRoot) {
        this.payloadRoot = payloadRoot;
    }

    public int getBreakpointTimeoutSeconds() {
        return breakpointTimeoutSeconds;
    }

    public void setBreakpointTimeoutSeconds(int breakpointTimeoutSeconds) {
        this.breakpointTimeoutSeconds = breakpointTimeoutSeconds;
    }

    public String getDemoBaseUrl() {
        return demoBaseUrl;
    }

    public void setDemoBaseUrl(String demoBaseUrl) {
        this.demoBaseUrl = demoBaseUrl;
    }

    public int getDemoRequestTimeoutMs() {
        return demoRequestTimeoutMs;
    }

    public void setDemoRequestTimeoutMs(int demoRequestTimeoutMs) {
        this.demoRequestTimeoutMs = demoRequestTimeoutMs;
    }
}
