# API 接口契约

## 1. Session API

### POST /api/session/start-record

创建记录 session。

请求：

```json
{
  "serviceName": "instrument-service-demo",
  "operator": "developer",
  "remark": "record flow"
}
```

响应：

```json
{
  "success": true,
  "sessionId": "record-xxx",
  "recording": true,
  "debugging": false,
  "mode": "record"
}
```

### POST /api/session/stop-record

停止记录。

响应：

```json
{
  "success": true,
  "sessionId": "record-xxx",
  "recording": false,
  "debugging": false,
  "mode": "idle"
}
```

### POST /api/session/start-debug

开始调试。

响应：

```json
{
  "success": true,
  "sessionId": "debug-xxx",
  "recording": true,
  "debugging": true,
  "mode": "debug"
}
```

### POST /api/session/stop-debug

停止调试并释放所有暂停调用。

响应：

```json
{
  "success": true,
  "releasedCount": 2,
  "recording": false,
  "debugging": false,
  "mode": "idle"
}
```

## 2. State API

### GET /api/debug/state

响应：

```json
{
  "recording": true,
  "debugging": false,
  "mode": "record",
  "sessionId": "record-xxx",
  "callCount": 3,
  "discoveredInterfaceCount": 2,
  "breakpointCount": 0,
  "pausedCount": 0
}
```

## 3. Call API

### POST /api/calls/before

Java AOP 调用。

请求：

```json
{
  "callId": "uuid",
  "serviceName": "instrument-service-demo",
  "className": "com.example.instrumentdemo.service.InstrumentServiceImpl",
  "methodName": "instrumentControl",
  "displayName": "通过槽位号操作仪器仪表",
  "description": "通过槽位号转换hid号，操作对应仪器仪表实例",
  "threadName": "http-nio-8080-exec-1",
  "timestamp": 1710000000000,
  "args": {
    "instType": "VNA",
    "cmdName": "create",
    "slotId": 1,
    "params": {}
  },
  "parameterMeta": [
    {
      "name": "instType",
      "displayName": "仪表类型",
      "description": "仪表类型",
      "javaType": "java.lang.String"
    }
  ]
}
```

响应未暂停：

```json
{
  "success": true,
  "callIndex": 1,
  "action": "continue"
}
```

响应暂停：

```json
{
  "success": true,
  "callIndex": 2,
  "action": "pause",
  "reason": "matched breakpoint",
  "waitTimeoutMs": 300000,
  "breakpointId": "bp-xxx"
}
```

### POST /api/calls/after

请求：

```json
{
  "callId": "uuid",
  "success": true,
  "costMs": 500,
  "result": {
    "code": 0,
    "message": "control success",
    "data": {}
  },
  "exceptionType": null,
  "exceptionMessage": null
}
```

响应：

```json
{
  "success": true
}
```

### GET /api/calls

查询调用记录。

参数：

```text
sessionId
keyword
status
methodName
serviceName
sortBy
sortOrder
page
pageSize
```

### GET /api/calls/{callId}

查询调用详情。

### GET /api/calls/{callId}/wait

Java 命中断点后等待。

响应：

```json
{
  "action": "continue"
}
```

或：

```json
{
  "action": "timeout_continue"
}
```

### POST /api/calls/{callId}/continue

继续指定调用。

响应：

```json
{
  "success": true
}
```

### POST /api/calls/continue-all

继续全部。

响应：

```json
{
  "success": true,
  "releasedCount": 3
}
```

## 4. Interface API

### GET /api/interfaces

查询已发现接口。

参数：

```text
sessionId
serviceName
keyword
sortBy
sortOrder
page
pageSize
```

### GET /api/interfaces/{interfaceId}

查询接口详情。

### POST /api/interfaces/{interfaceId}/breakpoint

从接口创建断点。

请求：

```json
{
  "name": "instrumentControl breakpoint",
  "enabled": true,
  "hitMode": "always"
}
```

## 5. Breakpoint API

### POST /api/calls/{callId}/breakpoint

从调用记录创建断点。

请求：

```json
{
  "mode": "method_with_args",
  "name": "control create breakpoint",
  "enabled": true,
  "selectedArgs": ["cmdName"],
  "hitMode": "always"
}
```

### GET /api/breakpoints

查询断点。

### POST /api/breakpoints

手动创建断点。

### DELETE /api/breakpoints/{breakpointId}

删除断点。

### POST /api/breakpoints/{breakpointId}/enable

启用断点。

### POST /api/breakpoints/{breakpointId}/disable

禁用断点。

## 6. Java Demo REST API

这些接口由 Python 桌面端“Java 调用”Tab 主动调用。

```text
GET http://127.0.0.1:8080/api/demo/ping
GET http://127.0.0.1:8080/api/demo/initialize
GET http://127.0.0.1:8080/api/demo/control?instType=VNA&cmdName=create&slotId=1
GET http://127.0.0.1:8080/api/demo/control?instType=VNA&cmdName=start&slotId=1
GET http://127.0.0.1:8080/api/demo/control?instType=VNA&cmdName=stop&slotId=1
GET http://127.0.0.1:8080/api/demo/error
```
