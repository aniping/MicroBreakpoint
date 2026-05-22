package com.example.instrumentdemo.debuger;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class DebugClient {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public static WaitResponse waitContinue(String callId) {
        String url = DebuggerSettings.serverUrl + "/api/calls/" + callId + "/wait";

        try {
            String responseBody = getJson(url, DebuggerSettings.breakpointTimeoutMs);

            if (responseBody.isEmpty()) {
                return new WaitResponse("timeout_continue");
            }

            return OBJECT_MAPPER.readValue(responseBody, WaitResponse.class);
        } catch (Exception e) {
            System.out.println("[MicroBreakpoint] wait failed, continue business. callId="
                    + callId
                    + ", error="
                    + e.getMessage());

            return new WaitResponse("timeout_continue");
        }
    }

    private static String getJson(String url, int readTimeoutMs) throws Exception {
        HttpURLConnection connection = null;

        try {
            URL targetUrl = new URL(url);
            connection = (HttpURLConnection) targetUrl.openConnection();

            connection.setRequestMethod("GET");
            connection.setConnectTimeout(DebuggerSettings.connectTimeoutMs);
            connection.setReadTimeout(readTimeoutMs);
            connection.setRequestProperty("Accept", "application/json");

            int status = connection.getResponseCode();

            if (status < 200 || status >= 300) {
                throw new RuntimeException("HTTP " + status);
            }

            try (java.io.InputStream inputStream = connection.getInputStream();
                 java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream()) {

                byte[] data = new byte[1024];
                int nRead;

                while ((nRead = inputStream.read(data, 0, data.length)) != -1) {
                    buffer.write(data, 0, nRead);
                }

                return new String(buffer.toByteArray(), java.nio.charset.StandardCharsets.UTF_8);
            }
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    public static BeforeCallResponse beforeCall(BeforeCallRequest request) {
        String url = DebuggerSettings.serverUrl + "/api/calls/before";

        try {
            String responseBody = postJson(url, request, DebuggerSettings.readTimeoutMs);

            if (responseBody.isEmpty()) {
                return new BeforeCallResponse(true, null, "continue", "empty response", null, null, null, null);
            }

            return OBJECT_MAPPER.readValue(responseBody, BeforeCallResponse.class);
        } catch (Exception e) {
            System.out.println("[MicroBreakpoint] before-call http failed, continue. method="
                    + request.getMethodName()
                    + ", error="
                    + e.getMessage());

            return new BeforeCallResponse(false, null, "continue", "http failed", null, null, null, null);
        }
    }

    public static void afterCall(AfterCallRequest request) {
        String url = DebuggerSettings.serverUrl + "/api/calls/after";

        try {
            postJson(url, request, DebuggerSettings.readTimeoutMs);
        } catch (Exception e) {
            System.out.println("[MicroBreakpoint] after-call http failed, ignore. callId="
                    + request.getCallId()
                    + ", error="
                    + e.getMessage());
        }
    }

    private static String postJson(String url, Object body, int readTimeoutMs) throws Exception {
        String json = OBJECT_MAPPER.writeValueAsString(body);
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);

        HttpURLConnection connection = null;

        try {
            URL targetUrl = new URL(url);
            connection = (HttpURLConnection) targetUrl.openConnection();

            connection.setRequestMethod("POST");
            connection.setConnectTimeout(DebuggerSettings.connectTimeoutMs);
            connection.setReadTimeout(readTimeoutMs);
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json;charset=UTF-8");
            connection.setRequestProperty("Accept", "application/json");

            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(bytes);
            }

            int status = connection.getResponseCode();

            if (status < 200 || status >= 300) {
                throw new RuntimeException("HTTP " + status);
            }

            if (connection.getInputStream() == null) {
                return "";
            }

            return new String(connection.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }
}
