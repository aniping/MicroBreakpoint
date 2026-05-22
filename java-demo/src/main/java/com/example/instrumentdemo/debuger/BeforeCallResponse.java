package com.example.instrumentdemo.debuger;

public class BeforeCallResponse {

    private boolean success;
    private Integer callIndex;
    private String action;
    private String reason;
    private Long waitTimeoutMs;
    private String breakpointId;
    private String interfaceId;

    public BeforeCallResponse() {
    }

    public BeforeCallResponse(
            boolean success,
            Integer callIndex,
            String action,
            String reason,
            Long waitTimeoutMs,
            String breakpointId,
            String interfaceId
    ) {
        this.success = success;
        this.callIndex = callIndex;
        this.action = action;
        this.reason = reason;
        this.waitTimeoutMs = waitTimeoutMs;
        this.breakpointId = breakpointId;
        this.interfaceId = interfaceId;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public Integer getCallIndex() {
        return callIndex;
    }

    public void setCallIndex(Integer callIndex) {
        this.callIndex = callIndex;
    }

    public String getAction() {
        return action;
    }

    public void setAction(String action) {
        this.action = action;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public Long getWaitTimeoutMs() {
        return waitTimeoutMs;
    }

    public void setWaitTimeoutMs(Long waitTimeoutMs) {
        this.waitTimeoutMs = waitTimeoutMs;
    }

    public String getBreakpointId() {
        return breakpointId;
    }

    public void setBreakpointId(String breakpointId) {
        this.breakpointId = breakpointId;
    }

    public String getInterfaceId() {
        return interfaceId;
    }

    public void setInterfaceId(String interfaceId) {
        this.interfaceId = interfaceId;
    }
}
