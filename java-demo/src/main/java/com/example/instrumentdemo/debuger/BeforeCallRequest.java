package com.example.instrumentdemo.debuger;

import lombok.Getter;
import lombok.Setter;

import java.util.List;
import java.util.Map;

@Setter
@Getter
public class BeforeCallRequest {

    private String callId;
    private String serviceName;
    private String className;
    private String methodName;
    private String displayName;
    private String description;
    private String threadName;
    private long timestamp;
    private Map<String, Object> args;
    private List<DebugParam> parameterMeta;
}
