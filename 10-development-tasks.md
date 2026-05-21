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
