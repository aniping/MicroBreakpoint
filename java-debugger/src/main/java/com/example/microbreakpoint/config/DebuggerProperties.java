package com.example.microbreakpoint.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "micro-breakpoint")
public class DebuggerProperties {

    private String database = "../python-debugger/data/debugger.sqlite3";
    private String payloadRoot;
    private String settingsFile = "../python-debugger/data/settings.json";
    private int breakpointTimeoutSeconds = 300;
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

    public String getSettingsFile() {
        return settingsFile;
    }

    public void setSettingsFile(String settingsFile) {
        this.settingsFile = settingsFile;
    }

    public int getBreakpointTimeoutSeconds() {
        return breakpointTimeoutSeconds;
    }

    public void setBreakpointTimeoutSeconds(int breakpointTimeoutSeconds) {
        this.breakpointTimeoutSeconds = breakpointTimeoutSeconds;
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
