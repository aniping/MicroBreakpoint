# Java 微服务 Demo 开发说明

## 1. 技术栈

```text
Java 17+
Spring Boot 3.x
Spring Web
Spring AOP
Maven
Jackson
RestTemplate
```

服务端口：

```text
8080
```

## 2. 目录结构

```text
java-demo/
├── pom.xml
├── README.md
└── src/main/
    ├── java/com/example/instrumentdemo/
    │   ├── InstrumentDemoApplication.java
    │   ├── annotation/
    │   │   ├── EntryDefine.java
    │   │   ├── Description.java
    │   │   └── ParameterDefine.java
    │   ├── aspect/
    │   │   └── DebugBreakpointAspect.java
    │   ├── client/
    │   │   ├── DebugClient.java
    │   │   └── dto/
    │   ├── config/
    │   │   ├── DebuggerProperties.java
    │   │   └── RestTemplateConfig.java
    │   ├── controller/
    │   │   └── InstrumentController.java
    │   ├── model/
    │   │   └── ValueResult.java
    │   └── service/
    │       ├── InstrumentService.java
    │       └── InstrumentServiceImpl.java
    └── resources/
        └── application.yml
```

## 3. 注解设计

### EntryDefine

用于标记需要被断点程序追踪的方法。

字段：

```text
value：接口中文名称
```

### Description

用于描述接口或参数。

字段：

```text
value：描述信息
```

### ParameterDefine

用于描述方法参数。

字段：

```text
value：参数展示名称
```

## 4. 模拟业务接口

InstrumentService 必须包含：

```text
instrumentInitialize(String instType, String indexId, Map<String,Object> params)
instrumentControl(String instType, String cmdName, int slotId, Map<String,Object> params)
```

instrumentInitialize 行为：

```text
模拟 sleep 300ms
返回 ValueResult.success("initialize success")
```

instrumentControl 行为：

```text
模拟 sleep 500ms
如果 cmdName=error，抛出 RuntimeException
否则返回 ValueResult.success("control success: " + cmdName)
```

## 5. REST Controller 触发入口

Controller 必须是 Java 微服务调用链的入口。

必须提供：

```text
GET /api/demo/ping
```

返回：

```text
pong
```

用于 Python 桌面端测试 Java 服务是否在线。

```text
GET /api/demo/initialize
```

内部调用：

```text
instrumentInitialize("VNA", "1", params)
```

```text
GET /api/demo/control
```

Query 参数：

```text
instType，默认 VNA
cmdName，默认 create
slotId，默认 1
```

内部调用：

```text
instrumentControl(instType, cmdName, slotId, params)
```

```text
GET /api/demo/error
```

内部调用：

```text
instrumentControl("VNA", "error", 1, params)
```

## 6. AOP 拦截规则

拦截所有带 @EntryDefine 的方法。

注意：Controller 本身可以不加 @EntryDefine，应该拦截 Service 方法。

AOP 需要提取：

```text
callId
serviceName
className
methodName
displayName
description
threadName
timestamp
args
parameterMeta
```

before-call 上报成功后：

```text
如果 action=continue，直接执行真实方法
如果 action=pause，调用 Python wait 接口阻塞，释放后执行真实方法
```

after-call 必须无论成功或异常都上报。

## 7. DebugClient 设计

DebugClient 负责访问 Python Flask。

接口：

```text
reportBefore
reportAfter
waitUntilContinue
```

Python 地址从 application.yml 读取。

配置：

```text
debugger.enabled=true
debugger.server-url=http://127.0.0.1:5050
debugger.service-name=instrument-service-demo
debugger.connect-timeout-ms=300
debugger.read-timeout-ms=1000
debugger.breakpoint-timeout-ms=300000
```

容错要求：

```text
Python 不在线时 Java 业务不能失败
before-call 异常直接放行
after-call 异常只打印日志
wait 异常直接放行
wait 超时自动放行
```
