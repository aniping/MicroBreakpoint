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
import org.springframework.stereotype.Component;

@Aspect
@Component
public class DebugBreakpointAspect {
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

        BeforeCallResponse beforeResponse = debugClient.reportBefore(before);
        if ("pause".equalsIgnoreCase(beforeResponse.getAction())) {
            debugClient.waitUntilContinue(callId);
        }

        long start = System.currentTimeMillis();
        Object result = null;
        Throwable failure = null;
        try {
            result = joinPoint.proceed();
            return result;
        } catch (Throwable t) {
            failure = t;
            throw t;
        } finally {
            long costMs = System.currentTimeMillis() - start;
            debugClient.reportAfter(new AfterCallRequest(
                    callId,
                    failure == null,
                    costMs,
                    result,
                    failure == null ? null : failure.getClass().getName(),
                    failure == null ? null : failure.getMessage()));
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
