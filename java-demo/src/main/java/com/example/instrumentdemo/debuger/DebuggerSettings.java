package com.example.instrumentdemo.debuger;

public class DebuggerSettings {

    public static boolean enabled = true;

    public static String serverUrl = "http://127.0.0.1:5050";

    public static String serviceName = "instrument-service";

    public static int connectTimeoutMs = 300;

    public static int readTimeoutMs = 1000;

    public static int breakpointTimeoutMs = 300000;

    private DebuggerSettings() {
    }
}
