package com.example.instrumentdemo.debuger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

class DebugInvokerTest {

    @Test
    void buildBeforeCallRequestPromotesBusinessParams() {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("mode", "AUTO");
        params.put("power", -10);

        DebugMethodInfo methodInfo = DebugMethodInfo.commonMethodData("SA", "start", "instrumentControl", 1, params);

        BeforeCallRequest request = DebugInvoker.buildBeforeCallRequest("call-1", methodInfo);

        assertEquals("call-1", request.getCallId());
        assertEquals("SA", request.getObjectName());
        assertEquals("start", request.getCmdName());
        assertEquals(1, request.getSlotId());
        assertEquals(params, request.getParams());
        assertEquals(params, request.getRawArgs().get("params"));
        assertEquals("instrumentControl", request.getMethodName());
        assertNotNull(request.getParameterMeta());
    }
}
