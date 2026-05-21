package com.example.instrumentdemo.client.dto;

public record AfterCallRequest(
        String callId,
        boolean success,
        long costMs,
        Object result,
        String exceptionType,
        String exceptionMessage) {
}
