package com.example.microbreakpoint.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "micro-breakpoint")
public class DebuggerProperties {

    private String database = "../python-debugger/data/debugger.sqlite3";
    private String payloadRoot;
    private int breakpointTimeoutSeconds = 300;
    private String demoBaseUrl = "http://127.0.0.1:8080";
    private int demoRequestTimeoutMs = 1000;
    private Long parentPid;
    private long parentCheckIntervalMs = 2000;
    private boolean parentWatchdogExitEnabled = true;

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

    public Long getParentPid() {
        return parentPid;
    }

    public void setParentPid(Long parentPid) {
        this.parentPid = parentPid;
    }

    public long getParentCheckIntervalMs() {
        return parentCheckIntervalMs;
    }

    public void setParentCheckIntervalMs(long parentCheckIntervalMs) {
        this.parentCheckIntervalMs = parentCheckIntervalMs;
    }

    public boolean isParentWatchdogExitEnabled() {
        return parentWatchdogExitEnabled;
    }

    public void setParentWatchdogExitEnabled(boolean parentWatchdogExitEnabled) {
        this.parentWatchdogExitEnabled = parentWatchdogExitEnabled;
    }
}
