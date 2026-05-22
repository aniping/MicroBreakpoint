# MicroBreakpoint

MicroBreakpoint 是一个面向 Java 微服务的接口级断点调试 Demo。它由两部分组成：

- `java-demo/`：Spring Boot 3 微服务示例，提供仪表初始化和控制接口，并通过 AOP 上报调用。
- `python-debugger/`：Flask 后端 + SQLite + PySide6/QML 桌面端，用于 Session 化采集调用、动态发现接口、设置断点并控制 Java 请求继续执行。

关键原则：当前模型只有“开始调试 / 停止调试”。点击“开始调试”后，Java 上报的 before-call 才会进入调用记录、接口发现和断点判断；停止调试后新的 before-call 会直接放行，不污染当前 Session。Java 调用由外部脚本、业务系统或手动 HTTP 请求触发，桌面端不再承担 Java 请求发起器职责。

## 环境

Python 使用 conda 环境管理：

```powershell
conda env create -f environment.yml
conda activate micro-breakpoint
```

Java 需要 JDK 17+ 和 Maven，Demo 代码不依赖 IDE Lombok 插件或额外注解处理配置。

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

推荐开发验证顺序：

1. 启动或打开桌面端，确认 Python 后端可用。
2. 启动 Java Demo。
3. 在桌面端创建或打开 Session，再点击“开始调试”。
4. 通过脚本、接口工具或真实业务流量触发 Java Demo 接口。

## 界面主题

桌面端支持暗色模式和亮色模式。顶部标题栏右侧的主题按钮可快速切换亮暗主题，“设置”页的“外观”区域也可以选择暗色或亮色。

主题选择会通过桌面端配置持久化，退出并重新启动后会保持上次选择。默认主题为暗色。

主题系统集中管理窗口背景、顶部栏、工具栏、侧边栏、面板、文字、输入框、状态标签和 JSON 查看区域的颜色，避免各页面散落大面积硬编码颜色。

## 验收流程

1. 桌面端进入“历史会话”，点击“新建 Session”或选择已有 Session。
2. 点击“开始调试”。
3. 手动调用 Java Demo 的 `POST /api/demo/control` 或真实业务接口。
4. “调用记录”页应出现当前 Session 的调用记录，并按 `objectName` 可折叠分组展示 `cmdName`、`slotId` 和 `params` 摘要；每个分组内支持搜索、状态过滤、断点命中过滤、表头排序、列宽拖拽和分页。
5. “已发现接口”页应按 `objectName` 可折叠分组展示接口、参数样本数、唯一键、断点状态和业务别名；别名默认文本展示，点击“编辑”后再进入输入态。
6. 从已发现接口创建命令断点，或从调用记录创建命令断点 / 参数快照断点。
7. 再次触发同一业务接口，命中断点后调用状态应变为 `paused`，顶部会出现暂停提示条。
8. 点击“继续执行”或“继续全部”后 Java 请求恢复，状态最终变为 `finished`。
9. 点击“停止调试”后，再触发 Java 接口不会新增调用记录；再次开始同一 Session 时会继续追加数据。

## 验证命令

```powershell
cd python-debugger
conda run -n micro-breakpoint pytest

cd ..\java-demo
mvn test
```
