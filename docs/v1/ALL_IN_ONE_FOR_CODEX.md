# ===== README.md =====

# MicroBreakpoint Codex 开发指导文件

本文件包用于指导 Codex 在本地开发一个完整的 Java 微服务接口断点调试 Demo。

注意：

1. 本次文件包是重新生成的，不基于旧 zip 修改。
2. 文件名全部使用英文，避免 Windows 解压后文件名乱码。
3. 文件内容统一使用 UTF-8 编码。
4. 断点程序启动时不知道 Java 微服务有哪些接口。
5. 必须先点击“开始记录”，再通过桌面端的“Java 调用”页面主动调用 Java 微服务接口，Java AOP 才会拦截并上报。
6. “开始记录”本身不会自动调用 Java 微服务。

推荐本地目录：

```text
micro-breakpoint/
├── docs/
│   ├── README.md
│   ├── 01-final-design.md
│   ├── 02-codex-main-prompt.md
│   ├── 03-java-demo-design.md
│   ├── 04-python-debugger-design.md
│   ├── 05-api-contract.md
│   ├── 06-database-design.md
│   ├── 07-qml-ui-design.md
│   ├── 08-java-call-trigger-design.md
│   ├── 09-acceptance-tests.md
│   └── 10-development-tasks.md
├── java-demo/
└── python-debugger/
```

建议让 Codex 优先读取：

```text
02-codex-main-prompt.md
08-java-call-trigger-design.md
09-acceptance-tests.md
```


# ===== 01-final-design.md =====

# MicroBreakpoint 最终方案

## 1. 项目定位

MicroBreakpoint 是一个面向 Java 微服务的接口级断点调试工具。

它的核心能力：

```text
记录 Java 微服务真实执行过程中调用过的接口
动态发现接口定义、参数结构和调用顺序
基于已发现接口或调用记录设置断点
再次执行微服务流程时命中断点并暂停 Java 方法调用
在桌面端点击继续后恢复 Java 方法执行
```

关键原则：

```text
断点程序启动时，不预先知道 Java 微服务有哪些接口。
接口信息必须通过 Java 微服务实际调用时主动上报。
用户先记录，再触发 Java 调用，再发现接口，再设置断点，再调试。
```

## 2. 系统组成

```text
micro-breakpoint/
├── java-demo/          Spring Boot 微服务 Demo
└── python-debugger/    Python 断点调试程序
```

### 2.1 Spring Boot 微服务 Demo

职责：

```text
提供模拟业务接口
使用 Spring AOP 拦截目标方法
在方法执行前上报 before-call
在方法执行后上报 after-call
收到暂停指令后阻塞等待
收到继续指令或等待超时后恢复执行
```

### 2.2 Python 断点调试程序

由 Flask 后端和 PySide6/QML 桌面端组成。

职责：

```text
接收 Java 微服务上报
记录接口调用
动态发现接口
管理调试 Session
管理断点规则
判断是否命中断点
控制 Java 请求暂停与继续
提供桌面端可视化操作界面
主动触发 Java Demo REST 接口，形成完整闭环
```

## 3. 完整闭环

必须明确：点击“开始记录”只会让 Python 进入记录状态，不会自动调用 Java 微服务。

完整闭环如下：

```text
用户点击“开始记录”
  ↓
Python 进入 recording=true, debugging=false
  ↓
用户在桌面端“Java 调用”页面点击“调用 control-create”
  ↓
Python 桌面端请求 Java REST 接口 /api/demo/control?cmdName=create
  ↓
Java Controller 调用 InstrumentService.instrumentControl
  ↓
Spring AOP 拦截 @EntryDefine 方法
  ↓
Java 向 Python Flask 上报 before-call
  ↓
Python 保存调用记录并动态发现接口
  ↓
Python 返回 continue
  ↓
Java 执行业务方法
  ↓
Java 向 Python Flask 上报 after-call
  ↓
Python 更新返回值、异常、耗时
  ↓
桌面端展示调用记录和已发现接口
```

## 4. 运行状态

### Idle

```text
recording=false
debugging=false
mode=idle
```

不记录新调用，不触发断点，可查看历史和管理断点。

### Recording

```text
recording=true
debugging=false
mode=record
```

接收 Java 上报，保存调用记录，动态发现接口，不判断断点，不暂停 Java。

### Debugging

```text
recording=true
debugging=true
mode=debug
```

接收 Java 上报，保存调用记录，动态发现接口，判断断点规则，命中断点则暂停 Java。

## 5. 核心工作流

### 5.1 记录发现流程

```text
1. 启动 Python Flask 后端
2. 启动 PySide6/QML 桌面端
3. 启动 Spring Boot 微服务 Demo
4. 桌面端点击“开始记录”
5. Python 创建 record session
6. 桌面端进入“Java 调用”页面
7. 点击“调用 initialize / control-create / control-start / error”等按钮
8. Python 桌面端向 Java REST 接口发请求
9. Java Controller 调用业务 Service
10. Java AOP 拦截 Service 方法
11. Java 向 Python 上报 before-call
12. Python 创建调用记录并动态发现接口
13. Python 返回 continue
14. Java 执行业务方法
15. Java 向 Python 上报 after-call
16. Python 更新结果、异常、耗时和接口统计
17. 用户点击“停止记录”
18. 页面展示调用记录和已发现接口
```

### 5.2 断点设置流程

断点只能基于：

```text
已发现接口
历史调用记录
```

从已发现接口创建断点：

```text
methodName = instrumentControl
condition = 空
```

从调用记录创建条件断点：

```text
methodName = instrumentControl
condition:
  instType = VNA
  cmdName = create
  slotId = 1
```

### 5.3 断点调试流程

```text
1. 用户设置断点
2. 用户点击“开始调试”
3. Python 创建 debug session
4. 用户在“Java 调用”页面再次点击 control-create
5. Python 桌面端请求 Java REST 接口
6. Java Controller 调用 Service
7. Java AOP 上报 before-call
8. Python 创建调用记录并判断断点
9. 如果未命中，返回 continue
10. 如果命中，返回 pause
11. Java 调用 /api/calls/{callId}/wait 并阻塞
12. 桌面端显示该调用 paused
13. 用户点击“继续执行”
14. Python 释放对应 callId
15. Java 恢复执行业务方法
16. Java 上报 after-call
17. Python 更新调用状态为 finished 或 exception
```


# ===== 02-codex-main-prompt.md =====

# Codex 开发总 Prompt

你是一个资深全栈工程师，请在当前目录从零开发一个名为 MicroBreakpoint 的完整 Demo 项目。

项目包含两个子项目：

```text
micro-breakpoint/
├── java-demo/
└── python-debugger/
```

## 一、核心目标

开发一个 Java 微服务接口级断点调试工具。

关键要求：

```text
1. Python 断点程序启动时不知道 Java 微服务有哪些接口。
2. 用户点击“开始记录”后，Python 只进入记录状态，不会自动调用 Java。
3. 必须在 Python 桌面端提供“Java 调用”页面，由用户点击按钮主动调用 Java Demo REST 接口。
4. Java REST Controller 被调用后，再调用 Service 方法。
5. Service 方法带 @EntryDefine 注解，被 Spring AOP 拦截。
6. AOP 在方法执行前向 Python Flask 上报 before-call。
7. Python 根据上报信息保存调用记录并动态发现接口。
8. AOP 在方法执行后向 Python Flask 上报 after-call。
9. 停止记录后，页面展示调用记录和已发现接口。
10. 用户从已发现接口或调用记录创建断点。
11. 点击“开始调试”后，再通过“Java 调用”页面调用 Java 接口。
12. 命中断点后 Java 请求阻塞。
13. 用户在桌面端点击“继续执行”后 Java 请求恢复。
```

请注意：

```text
开始记录 ≠ 调用 Java 微服务
开始记录 + 点击 Java 调用按钮 = 产生 Java 调用并触发 AOP 上报
```

## 二、技术栈

Java Demo：

```text
Java 17+
Spring Boot 3.x
Spring Web
Spring AOP
Maven
Jackson
RestTemplate
端口 8080
```

Python Debugger：

```text
Python 3.10+
Flask
Flask-CORS
SQLite
PySide6
QML
requests
端口 5050
```

## 三、Java Demo 必须实现

### 1. 模拟业务接口

InstrumentService：

```text
instrumentInitialize(String instType, String indexId, Map<String,Object> params)
instrumentControl(String instType, String cmdName, int slotId, Map<String,Object> params)
```

这两个方法必须带 @EntryDefine、@Description、@ParameterDefine 注解。

### 2. REST Controller

必须提供：

```text
GET /api/demo/ping
GET /api/demo/initialize
GET /api/demo/control?instType=VNA&cmdName=create&slotId=1
GET /api/demo/error
```

Controller 只是触发入口，必须调用 Service 方法，从而触发 AOP。

### 3. AOP

拦截所有带 @EntryDefine 的 Service 方法。

AOP 流程：

```text
生成 callId
提取 className、methodName、displayName、description
提取参数名、参数类型、参数注解、参数值
调用 Python POST /api/calls/before
如果返回 action=pause，则调用 GET /api/calls/{callId}/wait 阻塞
执行真实方法
捕获返回值或异常
计算耗时
调用 Python POST /api/calls/after
```

### 4. 容错

Python 不在线时 Java 业务必须正常执行。

```text
before-call 失败直接放行
after-call 失败只打印日志
wait 失败直接放行
所有请求必须有超时
```

## 四、Python Flask 必须实现

状态：

```text
Idle: recording=false, debugging=false
Recording: recording=true, debugging=false
Debugging: recording=true, debugging=true
```

API：

```text
POST /api/session/start-record
POST /api/session/stop-record
POST /api/session/start-debug
POST /api/session/stop-debug
GET  /api/debug/state
POST /api/calls/before
POST /api/calls/after
GET  /api/calls
GET  /api/calls/{callId}
POST /api/calls/{callId}/continue
POST /api/calls/continue-all
GET  /api/calls/{callId}/wait
GET  /api/interfaces
GET  /api/interfaces/{interfaceId}
POST /api/interfaces/{interfaceId}/breakpoint
POST /api/calls/{callId}/breakpoint
GET  /api/breakpoints
POST /api/breakpoints
DELETE /api/breakpoints/{breakpointId}
POST /api/breakpoints/{breakpointId}/enable
POST /api/breakpoints/{breakpointId}/disable
```

## 五、Python 桌面端必须实现

PySide6/QML 主窗口包含这些 Tab：

```text
调用记录
已发现接口
断点管理
历史会话
Java 调用
```

其中“Java 调用”Tab 是必须的，用于主动调用 Java Demo REST 接口。

Java 调用 Tab 必须包含：

```text
Java 服务地址输入框，默认 http://127.0.0.1:8080
测试连接按钮，调用 /api/demo/ping
调用 initialize 按钮，调用 /api/demo/initialize
调用 control-create 按钮，调用 /api/demo/control?cmdName=create
调用 control-start 按钮，调用 /api/demo/control?cmdName=start
调用 control-stop 按钮，调用 /api/demo/control?cmdName=stop
调用 error 按钮，调用 /api/demo/error
自定义 instType、cmdName、slotId 输入区
自定义调用按钮
调用结果展示区
```

## 六、验收主链路

必须能完成以下闭环：

```text
1. 启动 Python 后端
2. 启动 Python 桌面端
3. 启动 Java Demo
4. 桌面端点击“开始记录”
5. 桌面端进入“Java 调用”Tab
6. 点击“调用 initialize”
7. 点击“调用 control-create”
8. 调用记录 Tab 出现调用记录
9. 已发现接口 Tab 出现 instrumentInitialize 和 instrumentControl
10. 点击“停止记录”
11. 在已发现接口中给 instrumentControl 设置断点
12. 点击“开始调试”
13. 进入“Java 调用”Tab，再次点击 control-create
14. Java 请求被卡住
15. 调用记录显示 paused
16. 点击“继续执行”
17. Java 请求返回
18. 调用状态变为 finished
```

请直接生成完整可运行代码、README、启动说明和测试说明。


# ===== 03-java-demo-design.md =====

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


# ===== 04-python-debugger-design.md =====

# Python 断点程序开发说明

## 1. 技术栈

```text
Python 3.10+
Flask
Flask-CORS
SQLite
PySide6
QML
requests
```

Flask 端口：

```text
5050
```

## 2. 目录结构

```text
python-debugger/
├── README.md
├── requirements.txt
├── run_backend.py
├── run_desktop.py
├── app/
│   ├── __init__.py
│   ├── api/
│   │   ├── session_api.py
│   │   ├── call_api.py
│   │   ├── interface_api.py
│   │   ├── breakpoint_api.py
│   │   └── state_api.py
│   ├── db/
│   │   └── database.py
│   ├── models/
│   │   └── schema.sql
│   ├── services/
│   │   ├── state_service.py
│   │   ├── session_service.py
│   │   ├── call_record_service.py
│   │   ├── interface_discover_service.py
│   │   ├── breakpoint_service.py
│   │   └── wait_manager.py
│   └── utils/
│       ├── json_utils.py
│       └── time_utils.py
└── desktop/
    ├── main.py
    ├── bridge.py
    └── qml/
        ├── Main.qml
        ├── Toolbar.qml
        ├── CallRecordTab.qml
        ├── InterfaceTab.qml
        ├── BreakpointTab.qml
        ├── SessionTab.qml
        ├── JavaCallTab.qml
        └── DetailPanel.qml
```

## 3. 后端状态

### Idle

```text
recording=false
debugging=false
mode=idle
```

### Recording

```text
recording=true
debugging=false
mode=record
```

### Debugging

```text
recording=true
debugging=true
mode=debug
```

## 4. 服务模块

### StateService

维护当前状态：

```text
recording
debugging
mode
currentSessionId
callCount
discoveredInterfaceCount
breakpointCount
pausedCount
```

### SessionService

负责：

```text
开始记录
停止记录
开始调试
停止调试
创建 session
结束 session
查询历史 session
```

### CallRecordService

负责：

```text
创建调用记录
更新调用结果
更新调用状态
查询调用列表
查询调用详情
搜索
过滤
排序
```

### InterfaceDiscoverService

负责：

```text
根据 before-call 创建或更新 discovered_interface
更新接口调用次数
合并参数结构
保存样例参数
统计成功、异常、耗时
```

### BreakpointService

负责：

```text
创建断点
删除断点
启用断点
禁用断点
查询断点
判断调用是否命中断点
维护命中次数
```

### WaitManager

负责：

```text
创建等待对象
等待指定 callId
继续指定 callId
继续全部
超时释放
清理等待对象
```

必须线程安全。

## 5. before-call 处理逻辑

```text
1. 获取当前状态
2. 如果 recording=false，返回 continue，不记录
3. 如果 recording=true，创建 call_record
4. 创建或更新 discovered_interface
5. 如果 debugging=false，返回 continue
6. 如果 debugging=true，判断断点
7. 未命中断点，返回 continue
8. 命中断点，创建 wait event，状态设为 paused，返回 pause
```

## 6. after-call 处理逻辑

```text
1. 根据 callId 查找调用记录
2. 更新 result_json、success、exception、cost_ms
3. success=true 状态为 finished
4. success=false 状态为 exception
5. 更新 discovered_interface 统计信息
```

## 7. 桌面端 Bridge

Bridge 负责让 QML 调用：

```text
Python Flask API
Java Demo REST API
```

Java Demo REST API 默认地址：

```text
http://127.0.0.1:8080
```

Bridge 必须提供：

```text
startRecord
stopRecord
startDebug
stopDebug
loadState
loadCalls
loadInterfaces
loadBreakpoints
continueCall
continueAll
createBreakpointFromInterface
createBreakpointFromCall
javaPing
javaInitialize
javaControlCreate
javaControlStart
javaControlStop
javaError
javaCustomControl
```


# ===== 05-api-contract.md =====

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


# ===== 06-database-design.md =====

# 数据库设计

使用 SQLite。

## 1. debug_session

表示一次记录或调试会话。

字段：

```text
id TEXT PRIMARY KEY
mode TEXT
service_name TEXT
operator TEXT
start_time TEXT
end_time TEXT
recording INTEGER
debugging INTEGER
remark TEXT
created_at TEXT
updated_at TEXT
```

mode：

```text
record
debug
```

## 2. call_record

表示每一次接口调用。

字段：

```text
id INTEGER PRIMARY KEY AUTOINCREMENT
call_id TEXT UNIQUE
session_id TEXT
call_index INTEGER
service_name TEXT
class_name TEXT
method_name TEXT
display_name TEXT
description TEXT
thread_name TEXT
args_json TEXT
parameter_meta_json TEXT
result_json TEXT
success INTEGER
exception_type TEXT
exception_message TEXT
cost_ms INTEGER
status TEXT
breakpoint_id TEXT
created_at TEXT
updated_at TEXT
```

status：

```text
created
running
paused
continued
finished
exception
timeout
ignored
```

## 3. discovered_interface

表示动态发现的接口。

字段：

```text
id TEXT PRIMARY KEY
session_id TEXT
service_name TEXT
class_name TEXT
method_name TEXT
display_name TEXT
description TEXT
parameter_schema_json TEXT
sample_args_json TEXT
first_seen_at TEXT
last_seen_at TEXT
call_count INTEGER
success_count INTEGER
exception_count INTEGER
avg_cost_ms REAL
max_cost_ms INTEGER
min_cost_ms INTEGER
created_at TEXT
updated_at TEXT
```

唯一性建议：

```text
session_id + service_name + class_name + method_name 唯一
```

## 4. breakpoint

表示断点规则。

字段：

```text
id TEXT PRIMARY KEY
name TEXT
enabled INTEGER
service_name TEXT
class_name TEXT
method_name TEXT
display_name TEXT
condition_json TEXT
hit_mode TEXT
hit_count INTEGER
source_session_id TEXT
source_interface_id TEXT
source_call_id TEXT
created_at TEXT
updated_at TEXT
```

hit_mode：

```text
always
once
hit_count
```

## 5. 参数结构

parameter_schema_json 示例：

```json
{
  "instType": {
    "name": "instType",
    "displayName": "仪表类型",
    "description": "仪表类型",
    "javaType": "java.lang.String",
    "sample": "VNA"
  },
  "cmdName": {
    "name": "cmdName",
    "displayName": "仪表操作",
    "description": "仪表操作",
    "javaType": "java.lang.String",
    "sample": "create"
  },
  "slotId": {
    "name": "slotId",
    "displayName": "槽位id",
    "description": "槽位id",
    "javaType": "int",
    "sample": 1
  }
}
```

## 6. 断点条件

condition_json 示例：

```json
{
  "cmdName": "create",
  "slotId": 1
}
```

匹配规则：

```text
断点 enabled=true
methodName 匹配
serviceName 不为空时必须匹配
className 不为空时必须匹配
condition_json 为空时直接命中
condition_json 不为空时，args 中对应字段必须全部相等
```


# ===== 07-qml-ui-design.md =====

# QML 界面设计

## 1. 主窗口

标题：

```text
MicroBreakpoint - Java 微服务接口断点调试器
```

建议尺寸：

```text
1200 x 800
```

布局：

```text
顶部工具栏
状态栏
Tab 页面
左侧列表
右侧详情
```

## 2. 顶部工具栏

按钮：

```text
开始记录
停止记录
开始调试
停止调试
刷新
继续全部
清空筛选
```

按钮状态：

```text
Idle:
  开始记录可用
  开始调试可用
  停止记录不可用
  停止调试不可用

Recording:
  停止记录可用
  开始记录不可用
  开始调试不可用
  停止调试不可用

Debugging:
  停止调试可用
  继续全部可用
  开始记录不可用
  停止记录不可用
```

## 3. 状态栏

展示：

```text
当前状态
当前 sessionId
当前模式
调用总数
已发现接口数
断点数量
暂停中数量
```

示例：

```text
状态：调试中 | Session: debug-001 | 调用: 8 | 接口: 2 | 断点: 1 | 暂停: 1
```

## 4. Tab 页面

必须包含：

```text
调用记录
已发现接口
断点管理
历史会话
Java 调用
```

## 5. 调用记录 Tab

列表字段：

```text
调用序号
服务名
方法名
中文描述
状态
耗时
线程名
调用时间
是否命中断点
```

支持：

```text
搜索
状态过滤
方法过滤
服务过滤
排序
分页
```

右侧详情展示：

```text
callId
sessionId
callIndex
serviceName
className
methodName
displayName
description
threadName
status
args JSON
parameterMeta JSON
result JSON
exceptionType
exceptionMessage
costMs
breakpointId
createdAt
updatedAt
```

操作按钮：

```text
继续执行
按方法创建断点
按本次参数创建断点
复制入参
复制返回值
刷新详情
```

继续执行只在 paused 状态可用。

## 6. 已发现接口 Tab

列表字段：

```text
服务名
类名
方法名
中文名
调用次数
成功次数
异常次数
平均耗时
最后调用时间
```

右侧详情：

```text
interfaceId
sessionId
serviceName
className
methodName
displayName
description
parameterSchema
sampleArgs
callCount
successCount
exceptionCount
avgCostMs
maxCostMs
minCostMs
firstSeenAt
lastSeenAt
```

操作按钮：

```text
对此接口设置断点
查看相关调用
复制接口信息
```

## 7. 断点管理 Tab

列表字段：

```text
启用状态
断点名称
服务名
类名
方法名
条件
命中模式
命中次数
来源
创建时间
```

操作：

```text
新增断点
启用
禁用
删除
编辑条件
```

## 8. 历史会话 Tab

列表字段：

```text
sessionId
mode
serviceName
开始时间
结束时间
调用次数
发现接口数
异常数
备注
```

操作：

```text
打开会话
删除会话
导出会话
```

## 9. Java 调用 Tab

这是本项目闭环的关键页面。

必须包含：

```text
Java 服务地址输入框
默认值：http://127.0.0.1:8080
测试连接按钮
调用 initialize 按钮
调用 control-create 按钮
调用 control-start 按钮
调用 control-stop 按钮
调用 error 按钮
自定义 instType 输入框
自定义 cmdName 输入框
自定义 slotId 输入框
自定义调用按钮
调用结果展示区
```

按钮对应请求：

```text
测试连接 -> GET /api/demo/ping
initialize -> GET /api/demo/initialize
control-create -> GET /api/demo/control?instType=VNA&cmdName=create&slotId=1
control-start -> GET /api/demo/control?instType=VNA&cmdName=start&slotId=1
control-stop -> GET /api/demo/control?instType=VNA&cmdName=stop&slotId=1
error -> GET /api/demo/error
自定义调用 -> GET /api/demo/control?instType={instType}&cmdName={cmdName}&slotId={slotId}
```

用户典型操作：

```text
点击开始记录
进入 Java 调用 Tab
点击 initialize / control-create
回到调用记录 Tab 查看记录
回到已发现接口 Tab 查看动态发现的接口
```


# ===== 08-java-call-trigger-design.md =====

# Java 微服务调用触发设计

## 1. 为什么需要这个设计

仅点击“开始记录”不会产生任何 Java 接口调用。

“开始记录”只会让 Python 断点程序进入 recording 状态：

```text
recording=true
debugging=false
```

如果没有人调用 Java 微服务，Java AOP 不会执行，Python 也就不会收到 before-call / after-call 上报。

所以必须有一个明确的调用触发入口。

## 2. 正确闭环

```text
点击开始记录
  ↓
Python 进入记录状态
  ↓
用户点击桌面端“Java 调用”页面里的按钮
  ↓
Python 桌面端请求 Java REST 接口
  ↓
Java Controller 收到请求
  ↓
Java Controller 调用 InstrumentService
  ↓
Spring AOP 拦截 Service 方法
  ↓
Java 上报 Python before-call
  ↓
Python 记录调用并发现接口
  ↓
Java 执行业务
  ↓
Java 上报 Python after-call
```

## 3. Python 桌面端新增 Java 调用 Tab

必须新增：

```text
JavaCallTab.qml
```

页面包含：

```text
Java 服务地址输入框
测试连接按钮
调用 initialize 按钮
调用 control-create 按钮
调用 control-start 按钮
调用 control-stop 按钮
调用 error 按钮
自定义调用区域
调用结果展示区
```

默认 Java 服务地址：

```text
http://127.0.0.1:8080
```

## 4. Java Demo REST 接口

Spring Boot Demo 必须提供：

```text
GET /api/demo/ping
GET /api/demo/initialize
GET /api/demo/control
GET /api/demo/error
```

### ping

用途：测试 Java 服务是否在线。

```text
GET /api/demo/ping
```

返回：

```text
pong
```

### initialize

```text
GET /api/demo/initialize
```

Controller 内部必须调用：

```text
instrumentInitialize("VNA", "1", params)
```

### control

```text
GET /api/demo/control?instType=VNA&cmdName=create&slotId=1
```

Controller 内部必须调用：

```text
instrumentControl(instType, cmdName, slotId, params)
```

### error

```text
GET /api/demo/error
```

Controller 内部必须调用：

```text
instrumentControl("VNA", "error", 1, params)
```

## 5. Bridge 方法

Python 桌面端 Bridge 需要提供：

```text
javaPing(baseUrl)
javaInitialize(baseUrl)
javaControl(baseUrl, instType, cmdName, slotId)
javaError(baseUrl)
```

也可以提供便捷方法：

```text
javaControlCreate()
javaControlStart()
javaControlStop()
```

## 6. 记录发现使用流程

```text
1. 启动 Python 后端
2. 启动 Python 桌面端
3. 启动 Java Demo
4. 点击“开始记录”
5. 打开“Java 调用”Tab
6. 点击“测试连接”，确认返回 pong
7. 点击“调用 initialize”
8. 点击“调用 control-create”
9. 点击“调用 control-start”
10. 打开“调用记录”Tab，应看到 3 条记录
11. 打开“已发现接口”Tab，应看到 instrumentInitialize 和 instrumentControl
12. 点击“停止记录”
```

## 7. 断点调试使用流程

```text
1. 在“已发现接口”Tab 给 instrumentControl 设置断点
2. 点击“开始调试”
3. 打开“Java 调用”Tab
4. 点击“调用 control-create”
5. 由于命中断点，Java 请求应阻塞
6. 打开“调用记录”Tab，看到状态 paused
7. 点击“继续执行”
8. Java 请求返回
9. 调用状态变为 finished
```

## 8. Codex 必须注意

不要让“开始记录”自动调用 Java。

“开始记录”只是状态切换。

Java 调用必须由用户在“Java 调用”Tab 中主动触发。

这是为了模拟真实业务系统中：

```text
用户先打开记录，然后手动操作业务系统，让微服务真实跑一遍。
```


# ===== 09-acceptance-tests.md =====

# 验收测试流程

## 1. 启动

### 启动 Python Flask 后端

```text
cd python-debugger
pip install -r requirements.txt
python run_backend.py
```

### 启动 Python 桌面端

```text
cd python-debugger
python run_desktop.py
```

### 启动 Java Demo

```text
cd java-demo
mvn spring-boot:run
```

## 2. Java 服务连接测试

在桌面端打开“Java 调用”Tab。

确认 Java 服务地址为：

```text
http://127.0.0.1:8080
```

点击“测试连接”。

预期：

```text
返回 pong
```

## 3. 记录发现验收

步骤：

```text
1. 点击“开始记录”
2. 打开“Java 调用”Tab
3. 点击“调用 initialize”
4. 点击“调用 control-create”
5. 点击“调用 control-start”
6. 打开“调用记录”Tab
```

预期：

```text
至少 3 条调用记录
包含 instrumentInitialize
包含 instrumentControl
所有记录最终状态为 finished
```

继续：

```text
7. 打开“已发现接口”Tab
```

预期：

```text
出现 instrumentInitialize
出现 instrumentControl
instrumentControl 调用次数至少为 2
```

最后：

```text
8. 点击“停止记录”
```

预期：

```text
状态变为 idle
```

## 4. 方法断点验收

步骤：

```text
1. 打开“已发现接口”Tab
2. 选择 instrumentControl
3. 点击“对此接口设置断点”
4. 打开“断点管理”Tab
```

预期：

```text
出现 instrumentControl 断点
enabled=true
hitMode=always
```

继续：

```text
5. 点击“开始调试”
6. 打开“Java 调用”Tab
7. 点击“调用 control-create”
```

预期：

```text
Java 请求被卡住
调用记录中出现 status=paused
```

继续：

```text
8. 在调用记录中点击“继续执行”
```

预期：

```text
Java 请求返回
调用记录状态变为 finished
```

## 5. 条件断点验收

步骤：

```text
1. 从一条 cmdName=create 的调用记录创建条件断点
2. 条件字段选择 cmdName
3. 点击“开始调试”
4. 打开“Java 调用”Tab
5. 点击“调用 control-start”
```

预期：

```text
不暂停
请求正常返回
```

继续：

```text
6. 点击“调用 control-create”
```

预期：

```text
请求暂停
调用记录 status=paused
点击继续后恢复
```

## 6. 异常记录验收

步骤：

```text
1. 点击“开始记录”或“开始调试”
2. 打开“Java 调用”Tab
3. 点击“调用 error”
4. 打开“调用记录”Tab
```

预期：

```text
出现 instrumentControl 调用
状态为 exception
显示 exceptionType
显示 exceptionMessage
```

## 7. 停止调试释放等待验收

步骤：

```text
1. 设置 instrumentControl 方法断点
2. 点击“开始调试”
3. 点击“调用 control-create”，让请求暂停
4. 不点击继续执行
5. 点击“停止调试”
```

预期：

```text
所有 paused 调用被释放
Java 请求返回
状态变为 idle
```

## 8. Python 不在线容错验收

步骤：

```text
1. 停止 Python Flask 后端
2. 保持 Java Demo 运行
3. 浏览器直接访问 http://127.0.0.1:8080/api/demo/control?cmdName=create
```

预期：

```text
Java 请求仍然正常返回
不会因为 Python 不在线而失败
```


# ===== 10-development-tasks.md =====

# 开发任务拆解

## 1. Java Demo

任务：

```text
创建 Spring Boot 3 Maven 项目
添加 Web、AOP、Jackson 依赖
创建 ValueResult
创建 EntryDefine、Description、ParameterDefine 注解
创建 InstrumentService 接口
创建 InstrumentServiceImpl 实现
创建 InstrumentController
创建 DebuggerProperties
创建 RestTemplateConfig
创建 DebugClient
创建 DTO
创建 DebugBreakpointAspect
编写 application.yml
编写 README
```

验收：

```text
mvn spring-boot:run 成功
/api/demo/ping 返回 pong
/api/demo/initialize 正常返回
/api/demo/control 正常返回
/api/demo/error 返回异常响应或错误信息
Python 不启动时 Java 接口仍可正常访问
```

## 2. Python Flask 后端

任务：

```text
创建 Flask 项目
初始化 SQLite
实现 schema.sql
实现 StateService
实现 SessionService
实现 CallRecordService
实现 InterfaceDiscoverService
实现 BreakpointService
实现 WaitManager
实现 session_api
实现 state_api
实现 call_api
实现 interface_api
实现 breakpoint_api
实现 CORS
编写 README
```

验收：

```text
python run_backend.py 成功
/api/debug/state 可访问
/api/session/start-record 可切换状态
/api/calls/before 可创建调用记录
/api/calls/after 可更新调用记录
/api/interfaces 可看到动态发现接口
/api/breakpoints 可管理断点
/api/calls/{callId}/wait 和 continue 可完成阻塞释放
```

## 3. PySide6/QML 桌面端

任务：

```text
创建 run_desktop.py
创建 desktop/main.py
创建 Bridge
创建 Main.qml
创建 Toolbar.qml
创建 CallRecordTab.qml
创建 InterfaceTab.qml
创建 BreakpointTab.qml
创建 SessionTab.qml
创建 JavaCallTab.qml
创建 DetailPanel.qml
实现定时刷新状态和列表
实现点击按钮调用 Flask
实现 Java 调用按钮调用 Java Demo
```

验收：

```text
python run_desktop.py 成功打开窗口
可以开始记录和停止记录
可以开始调试和停止调试
Java 调用 Tab 可以 ping Java 服务
Java 调用 Tab 可以调用 initialize/control/error
调用记录 Tab 可以展示记录
已发现接口 Tab 可以展示接口
断点管理 Tab 可以管理断点
paused 调用可以继续执行
```

## 4. 闭环联调

任务：

```text
启动 Python 后端
启动 Python 桌面端
启动 Java Demo
开始记录
通过 Java 调用 Tab 触发 Java 接口
确认调用记录和接口发现
从接口创建断点
开始调试
再次通过 Java 调用 Tab 触发 Java 接口
确认 Java 请求暂停
点击继续执行
确认 Java 请求恢复
```

## 5. 重要实现约束

```text
不要让开始记录自动调用 Java
Java 调用必须在 Java 调用 Tab 中主动触发
Java AOP 必须拦截 Service 方法，而不是只拦截 Controller
Python 不在线不能影响 Java 业务
wait 必须有超时
停止调试必须释放全部等待
文件编码统一 UTF-8
README 必须写清启动和验收步骤
```
