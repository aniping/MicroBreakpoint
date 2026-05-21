package com.example.instrumentdemo.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "debugger")
public class DebuggerProperties {
    private boolean enabled = true;
    private String serverUrl = "http://127.0.0.1:5050";
    private String serviceName = "instrument-service-demo";
    private int connectTimeoutMs = 300;
    private int readTimeoutMs = 1000;
    private int breakpointTimeoutMs = 300000;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    public String getServerUrl() { return serverUrl; }
    public void setServerUrl(String serverUrl) { this.serverUrl = serverUrl; }
    public String getServiceName() { return serviceName; }
    public void setServiceName(String serviceName) { this.serviceName = serviceName; }
    public int getConnectTimeoutMs() { return connectTimeoutMs; }
    public void setConnectTimeoutMs(int connectTimeoutMs) { this.connectTimeoutMs = connectTimeoutMs; }
    public int getReadTimeoutMs() { return readTimeoutMs; }
    public void setReadTimeoutMs(int readTimeoutMs) { this.readTimeoutMs = readTimeoutMs; }
    public int getBreakpointTimeoutMs() { return breakpointTimeoutMs; }
    public void setBreakpointTimeoutMs(int breakpointTimeoutMs) { this.breakpointTimeoutMs = breakpointTimeoutMs; }
}
