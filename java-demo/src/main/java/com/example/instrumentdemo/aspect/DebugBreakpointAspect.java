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
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import java.lang.annotation.Annotation;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

@Aspect
@Component
public class DebugBreakpointAspect {
    private static final Logger log = LoggerFactory.getLogger(DebugBreakpointAspect.class);
    private final ObjectMapper objectMapper = new ObjectMapper();
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
        Map<String, Object> args = argsMap(method, joinPoint.getArgs());
        HttpRequestInfo httpInfo = httpRequestInfo(args);
        BeforeCallRequest before = new BeforeCallRequest(
                callId,
                properties.getServiceName(),
                joinPoint.getTarget().getClass().getName(),
                method.getName(),
                httpInfo.interfaceKey(),
                httpInfo.httpMethod(),
                httpInfo.requestUri(),
                httpInfo.querySignature(),
                httpInfo.bodySignature(),
                httpInfo.contentType(),
                entryDefine.value(),
                description == null ? "" : description.value(),
                Thread.currentThread().getName(),
                System.currentTimeMillis(),
                args,
                parameterMeta(method));

        log.info("[MicroBreakpoint] before-call report start callId={} method={} http={} uri={} interfaceKey={} thread={} args={}",
                callId, method.getName(), httpInfo.httpMethod(), httpInfo.requestUri(), httpInfo.interfaceKey(),
                Thread.currentThread().getName(), before.args());
        BeforeCallResponse beforeResponse = debugClient.reportBefore(before);
        log.info("[MicroBreakpoint] before-call report done callId={} method={} http={} uri={} action={} breakpointId={}",
                callId, method.getName(), httpInfo.httpMethod(), httpInfo.requestUri(),
                beforeResponse.getAction(), beforeResponse.getBreakpointId());
        if ("pause".equalsIgnoreCase(beforeResponse.getAction())) {
            log.info("[MicroBreakpoint] breakpoint paused callId={} method={} http={} uri={} breakpointId={} waiting for continue...",
                    callId, method.getName(), httpInfo.httpMethod(), httpInfo.requestUri(), beforeResponse.getBreakpointId());
            debugClient.waitUntilContinue(callId);
            log.info("[MicroBreakpoint] breakpoint resumed callId={} method={} http={} uri={} continue business",
                    callId, method.getName(), httpInfo.httpMethod(), httpInfo.requestUri());
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

    private HttpRequestInfo httpRequestInfo(Map<String, Object> args) {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes == null) {
            String bodySignature = canonicalJson(args);
            return new HttpRequestInfo("UNKNOWN", "no-http-request", "", bodySignature, "", interfaceKey("UNKNOWN", "no-http-request", "", bodySignature, ""));
        }
        HttpServletRequest request = attributes.getRequest();
        String httpMethod = request.getMethod() == null ? "UNKNOWN" : request.getMethod().toUpperCase();
        String requestUri = request.getRequestURI() == null ? "unknown" : request.getRequestURI();
        String querySignature = querySignature(request);
        String contentType = request.getContentType() == null ? "" : request.getContentType();
        String bodySignature = canonicalJson(args);
        return new HttpRequestInfo(httpMethod, requestUri, querySignature, bodySignature, contentType,
                interfaceKey(httpMethod, requestUri, querySignature, bodySignature, contentType));
    }

    private String querySignature(HttpServletRequest request) {
        Map<String, String[]> raw = new TreeMap<>(request.getParameterMap());
        Map<String, List<String>> normalized = new LinkedHashMap<>();
        raw.forEach((key, values) -> {
            List<String> list = new ArrayList<>(Arrays.asList(values));
            Collections.sort(list);
            normalized.put(key, list);
        });
        return canonicalJson(normalized);
    }

    private String canonicalJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value == null ? Map.of() : value);
        } catch (JsonProcessingException e) {
            return String.valueOf(value);
        }
    }

    private String interfaceKey(String httpMethod, String requestUri, String querySignature, String bodySignature, String contentType) {
        return httpMethod + " " + requestUri + "|" + querySignature + "|" + bodySignature + "|" + contentType;
    }

    private record HttpRequestInfo(
            String httpMethod,
            String requestUri,
            String querySignature,
            String bodySignature,
            String contentType,
            String interfaceKey) {
    }
}
