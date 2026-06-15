package com.example.instrumentdemo.debuger;

import static org.junit.jupiter.api.Assertions.assertFalse;

import java.net.InetSocketAddress;
import java.util.Map;

import com.sun.net.httpserver.HttpServer;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

class DebugClientTest {

    private HttpServer server;

    @AfterEach
    void tearDown() {
        if (server != null) {
            server.stop(0);
        }
        DebuggerSettings.enabled = false;
        DebuggerSettings.serverUrl = "http://127.0.0.1:18601";
        DebuggerSettings.connectTimeoutMs = 300;
        DebuggerSettings.readTimeoutMs = 1000;
        DebuggerSettings.breakpointTimeoutMs = 300000;
    }

    @Test
    void beforeCallFailureDisablesDebugger() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/api/calls/before", exchange -> {
            exchange.sendResponseHeaders(500, -1);
            exchange.close();
        });
        server.start();

        DebuggerSettings.enabled = true;
        DebuggerSettings.serverUrl = "http://127.0.0.1:" + server.getAddress().getPort();
        DebuggerSettings.connectTimeoutMs = 100;
        DebuggerSettings.readTimeoutMs = 100;

        BeforeCallRequest request = DebugInvoker.buildBeforeCallRequest("call-1",
                DebugMethodInfo.commonMethodData("SA", "start", "instrumentControl", 1, Map.of()));

        BeforeCallResponse response = DebugClient.beforeCall(request);

        assertFalse(response.isSuccess());
        assertFalse(DebuggerSettings.enabled);
    }
}
