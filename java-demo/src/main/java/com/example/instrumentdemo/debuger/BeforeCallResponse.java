package com.example.instrumentdemo.debuger;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
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

}
