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
