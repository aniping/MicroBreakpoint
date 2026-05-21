package com.example.instrumentdemo.client;

import com.example.instrumentdemo.client.dto.AfterCallRequest;
import com.example.instrumentdemo.client.dto.BeforeCallRequest;
import com.example.instrumentdemo.client.dto.BeforeCallResponse;
import com.example.instrumentdemo.client.dto.WaitResponse;
import com.example.instrumentdemo.config.DebuggerProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class DebugClient {
    private static final Logger log = LoggerFactory.getLogger(DebugClient.class);
    private final RestTemplate restTemplate;
    private final DebuggerProperties properties;

    public DebugClient(RestTemplate restTemplate, DebuggerProperties properties) {
        this.restTemplate = restTemplate;
        this.properties = properties;
    }

    public BeforeCallResponse reportBefore(BeforeCallRequest request) {
        if (!properties.isEnabled()) {
            return continueResponse();
        }
        try {
            BeforeCallResponse response = restTemplate.postForObject(url("/api/calls/before"), request, BeforeCallResponse.class);
            return response == null ? continueResponse() : response;
        } catch (Exception e) {
            log.warn("debug before-call failed, continue business: {}", e.getMessage());
            return continueResponse();
        }
    }

    public void reportAfter(AfterCallRequest request) {
        if (!properties.isEnabled()) {
            return;
        }
        try {
            restTemplate.postForObject(url("/api/calls/after"), request, Object.class);
        } catch (Exception e) {
            log.warn("debug after-call failed: {}", e.getMessage());
        }
    }

    public void waitUntilContinue(String callId) {
        if (!properties.isEnabled()) {
            return;
        }
        try {
            waitRestTemplate().getForObject(url("/api/calls/" + callId + "/wait"), WaitResponse.class);
        } catch (Exception e) {
            log.warn("debug wait failed, continue business: {}", e.getMessage());
        }
    }

    private BeforeCallResponse continueResponse() {
        BeforeCallResponse response = new BeforeCallResponse();
        response.setSuccess(true);
        response.setAction("continue");
        return response;
    }

    private String url(String path) {
        return properties.getServerUrl().replaceAll("/+$", "") + path;
    }

    private RestTemplate waitRestTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(properties.getConnectTimeoutMs());
        factory.setReadTimeout(properties.getBreakpointTimeoutMs() + 1000);
        return new RestTemplate(factory);
    }
}
