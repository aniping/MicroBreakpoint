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
