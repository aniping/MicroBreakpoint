package com.example.instrumentdemo.client.dto;

import java.util.List;
import java.util.Map;

public record BeforeCallRequest(
        String callId,
        String serviceName,
        String className,
        String methodName,
        String interfaceKey,
        String httpMethod,
        String requestUri,
        String querySignature,
        String bodySignature,
        String contentType,
        String displayName,
        String description,
        String threadName,
        long timestamp,
        Map<String, Object> args,
        List<ParameterMeta> parameterMeta) {
}
