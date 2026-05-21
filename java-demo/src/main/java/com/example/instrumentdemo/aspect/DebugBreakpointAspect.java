package com.example.instrumentdemo.aspect;

import com.example.instrumentdemo.annotation.Description;
import com.example.instrumentdemo.annotation.EntryDefine;
import com.example.instrumentdemo.annotation.ParameterDefine;
import com.example.instrumentdemo.client.DebugClient;
import com.example.instrumentdemo.client.dto.AfterCallRequest;
import com.example.instrumentdemo.client.dto.BeforeCallRequest;
import com.example.instrumentdemo.client.dto.BeforeCallResponse;
import com.example.instrumentdemo.client.dto.ParameterMeta;
import com.example.instrumentdemo.config.DebuggerProperties;
import java.lang.annotation.Annotation;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Aspect
@Component
public class DebugBreakpointAspect {
    private static final Logger log = LoggerFactory.getLogger(DebugBreakpointAspect.class);
    private final DebugClient debugClient;
    private final DebuggerProperties properties;

    public DebugBreakpointAspect(DebugClient debugClient, DebuggerProperties properties) {
        this.debugClient = debugClient;
        this.properties = properties;
    }

    @Around("@annotation(entryDefine)")
    public Object aroundEntry(ProceedingJoinPoint joinPoint, EntryDefine entryDefine) throws Throwable {
        String callId = UUID.randomUUID().toString();
        Method method = ((MethodSignature) joinPoint.getSignature()).getMethod();
        Description description = method.getAnnotation(Description.class);
        BeforeCallRequest before = new BeforeCallRequest(
                callId,
                properties.getServiceName(),
                joinPoint.getTarget().getClass().getName(),
                method.getName(),
                entryDefine.value(),
                description == null ? "" : description.value(),
                Thread.currentThread().getName(),
                System.currentTimeMillis(),
                argsMap(method, joinPoint.getArgs()),
                parameterMeta(method));

        log.info("[MicroBreakpoint] before-call report start callId={} method={} thread={} args={}",
                callId, method.getName(), Thread.currentThread().getName(), before.args());
        BeforeCallResponse beforeResponse = debugClient.reportBefore(before);
        log.info("[MicroBreakpoint] before-call report done callId={} method={} action={} breakpointId={}",
                callId, method.getName(), beforeResponse.getAction(), beforeResponse.getBreakpointId());
        if ("pause".equalsIgnoreCase(beforeResponse.getAction())) {
            log.info("[MicroBreakpoint] breakpoint paused callId={} method={} waiting for continue...",
                    callId, method.getName());
            debugClient.waitUntilContinue(callId);
            log.info("[MicroBreakpoint] breakpoint resumed callId={} method={} continue business",
                    callId, method.getName());
        }

        long start = System.currentTimeMillis();
        Object result = null;
        Throwable failure = null;
        try {
            log.info("[MicroBreakpoint] business invoke start callId={} method={}", callId, method.getName());
            result = joinPoint.proceed();
            log.info("[MicroBreakpoint] business invoke success callId={} method={}", callId, method.getName());
            return result;
        } catch (Throwable t) {
            failure = t;
            log.info("[MicroBreakpoint] business invoke exception callId={} method={} exception={} message={}",
                    callId, method.getName(), t.getClass().getName(), t.getMessage());
            throw t;
        } finally {
            long costMs = System.currentTimeMillis() - start;
            log.info("[MicroBreakpoint] after-call report start callId={} method={} success={} costMs={}",
                    callId, method.getName(), failure == null, costMs);
            debugClient.reportAfter(new AfterCallRequest(
                    callId,
                    failure == null,
                    costMs,
                    result,
                    failure == null ? null : failure.getClass().getName(),
                    failure == null ? null : failure.getMessage()));
            log.info("[MicroBreakpoint] after-call report done callId={} method={}", callId, method.getName());
        }
    }

    private Map<String, Object> argsMap(Method method, Object[] values) {
        Map<String, Object> args = new LinkedHashMap<>();
        Parameter[] parameters = method.getParameters();
        for (int i = 0; i < parameters.length; i++) {
            args.put(parameters[i].getName(), values[i]);
        }
        return args;
    }

    private List<ParameterMeta> parameterMeta(Method method) {
        List<ParameterMeta> meta = new ArrayList<>();
        for (Parameter parameter : method.getParameters()) {
            ParameterDefine define = findAnnotation(parameter, ParameterDefine.class);
            Description description = findAnnotation(parameter, Description.class);
            meta.add(new ParameterMeta(
                    parameter.getName(),
                    define == null ? parameter.getName() : define.value(),
                    description == null ? "" : description.value(),
                    parameter.getType().getName()));
        }
        return meta;
    }

    private <T extends Annotation> T findAnnotation(Parameter parameter, Class<T> type) {
        return parameter.getAnnotation(type);
    }
}
