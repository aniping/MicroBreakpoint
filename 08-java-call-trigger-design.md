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
