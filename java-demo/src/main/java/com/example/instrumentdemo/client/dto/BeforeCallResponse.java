package com.example.instrumentdemo.client.dto;

public class BeforeCallResponse {
    private boolean success;
    private int callIndex;
    private String action = "continue";
    private String reason;
    private long waitTimeoutMs;
    private String breakpointId;

    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }
    public int getCallIndex() { return callIndex; }
    public void setCallIndex(int callIndex) { this.callIndex = callIndex; }
    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public long getWaitTimeoutMs() { return waitTimeoutMs; }
    public void setWaitTimeoutMs(long waitTimeoutMs) { this.waitTimeoutMs = waitTimeoutMs; }
    public String getBreakpointId() { return breakpointId; }
    public void setBreakpointId(String breakpointId) { this.breakpointId = breakpointId; }
}
