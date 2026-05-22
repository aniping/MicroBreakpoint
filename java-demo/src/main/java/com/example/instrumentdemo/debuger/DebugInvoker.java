package com.example.instrumentdemo.debuger;

import java.util.UUID;

public class DebugInvoker {

    public static <T> T invoke(DebugMethodInfo methodInfo, DebugCallable<T> callable) {
        if (!DebuggerSettings.enabled) {
            return callBusiness(callable);
        }

        String callId = UUID.randomUUID().toString();
        long startTime = System.currentTimeMillis();

        BeforeCallRequest beforeRequest = buildBeforeCallRequest(callId, methodInfo);

        BeforeCallResponse beforeResponse = null;

        try {
            beforeResponse = DebugClient.beforeCall(beforeRequest);
            if (beforeResponse != null && "pause".equals(beforeResponse.getAction())) {
                System.out.println("[MicroBreakpoint] breakpoint hit, waiting. callId="
                        + callId
                        + ", method="
                        + methodInfo.getMethodName());

                try {
                    WaitResponse waitResponse = DebugClient.waitContinue(callId);

                    System.out.println("[MicroBreakpoint] wait finished. callId="
                            + callId
                            + ", action="
                            + (waitResponse == null ? null : waitResponse.getAction()));
                } catch (Exception e) {
                    System.out.println("[MicroBreakpoint] wait failed, continue business. callId="
                            + callId
                            + ", error="
                            + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.out.println("[MicroBreakpoint] before-call failed, continue business. error=" + e.getMessage());
        }

        try {
            T result = callable.call();

            long costMs = System.currentTimeMillis() - startTime;
            AfterCallRequest afterRequest = buildAfterSuccessRequest(callId, result, costMs);

            try {
                DebugClient.afterCall(afterRequest);
            } catch (Exception e) {
                System.out.println("[MicroBreakpoint] after-call failed, ignore. error=" + e.getMessage());
            }

            return result;
        } catch (RuntimeException e) {
            reportException(callId, startTime, e);
            throw e;
        } catch (Exception e) {
            reportException(callId, startTime, e);
            throw new RuntimeException(e);
        }
    }

    private static BeforeCallRequest buildBeforeCallRequest(String callId, DebugMethodInfo methodInfo) {
        BeforeCallRequest request = new BeforeCallRequest();
        request.setCallId(callId);
        request.setServiceName(methodInfo.getServiceName());
        request.setClassName(methodInfo.getClassName());
        request.setMethodName(methodInfo.getMethodName());
        request.setDisplayName(methodInfo.getDisplayName());
        request.setDescription(methodInfo.getDescription());
        request.setThreadName(Thread.currentThread().getName());
        request.setTimestamp(System.currentTimeMillis());
        request.setArgs(methodInfo.getArgs());
        request.setParameterMeta(methodInfo.getParameterMeta());
        return request;
    }

    private static AfterCallRequest buildAfterSuccessRequest(String callId, Object result, long costMs) {
        AfterCallRequest request = new AfterCallRequest();
        request.setCallId(callId);
        request.setSuccess(true);
        request.setCostMs(costMs);
        request.setResult(result);
        request.setExceptionType(null);
        request.setExceptionMessage(null);
        return request;
    }

    private static AfterCallRequest buildAfterExceptionRequest(String callId, Exception e, long costMs) {
        AfterCallRequest request = new AfterCallRequest();
        request.setCallId(callId);
        request.setSuccess(false);
        request.setCostMs(costMs);
        request.setResult(null);
        request.setExceptionType(e.getClass().getName());
        request.setExceptionMessage(e.getMessage());
        return request;
    }

    private static void reportException(String callId, long startTime, Exception e) {
        long costMs = System.currentTimeMillis() - startTime;
        AfterCallRequest afterRequest = buildAfterExceptionRequest(callId, e, costMs);

        try {
            DebugClient.afterCall(afterRequest);
        } catch (Exception reportError) {
            System.out.println("[MicroBreakpoint] after-call exception report failed, ignore. error=" + reportError.getMessage());
        }
    }

    private static <T> T callBusiness(DebugCallable<T> callable) {
        try {
            return callable.call();
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
