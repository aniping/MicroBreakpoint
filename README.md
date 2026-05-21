# MicroBreakpoint

MicroBreakpoint 是一个面向 Java 微服务的接口级断点调试 Demo。它由两部分组成：

- `java-demo/`：Spring Boot 3 微服务示例，提供仪表初始化和控制接口，并通过 AOP 上报调用。
- `python-debugger/`：Flask 后端 + SQLite + PySide6/QML 桌面端，用于记录调用、动态发现接口、设置断点并控制 Java 请求继续执行。

关键原则：点击“开始记录”只会切换 Python 调试器状态，不会自动调用 Java。必须在桌面端“Java 调用”页面主动点击按钮，Java Controller 调用 Service 后，AOP 才会上报 before-call / after-call。

## 环境

Python 使用 conda 环境管理：

```powershell
conda env create -f environment.yml
conda activate micro-breakpoint
```

Java 需要 JDK 17+ 和 Maven。

## 启动

启动 Python 后端：

```powershell
cd python-debugger
python run_backend.py
```

启动桌面端：

```powershell
cd python-debugger
python run_desktop.py
```

桌面端启动时会自动拉起 Python 后端；如果 `5050` 端口已经有后端在运行，桌面端会直接复用现有后端。

启动 Java Demo：

```powershell
cd java-demo
mvn spring-boot:run
```

## 验收流程

1. 桌面端进入“历史会话”，点击“新建会话”或选择已有会话。
2. 点击“开始记录”。
3. 进入“Java 调用”页，点击“测试连接”，应返回 `pong`。
4. 点击“调用 initialize”和“调用 control-create”。
5. “调用记录”页应出现当前会话的调用记录，“已发现接口”页应出现当前会话发现的 `instrumentInitialize` 和 `instrumentControl`。
6. 点击“停止记录”，对 `instrumentControl` 设置断点。
7. 点击“开始调试”，再次在“Java 调用”页点击 `control-create`。
8. 当前会话的调用记录状态应变为 `paused`，点击“继续执行”后 Java 请求恢复，状态最终变为 `finished`。

## 验证命令

```powershell
cd python-debugger
pytest

cd ..\java-demo
mvn test
```
