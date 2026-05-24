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

批量调用 Java Demo 的全部 REST 接口：

```powershell
cd java-demo
.\scripts\call-all-demo-apis.ps1
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
4. “调用记录”页应出现当前 Session 的调用记录，并按 `objectName` 可折叠分组展示 `cmdName`、`slotId` 和 `params` 摘要；每个分组内支持搜索、状态过滤、断点命中过滤、表头排序和中间列列宽拖拽，表格铺满分组宽度，页面底部显示全局总计。
5. “已发现接口”页应按 `objectName` 可折叠分组展示接口、参数样本数、唯一键、断点状态和整数平均耗时；接口卡片采用“主信息 / 指标网格 / 固定操作列”的三列布局，操作按钮统一对齐。
6. “已发现接口”右侧详情可查看同一接口的不同参数样本。参数样本是相同 `objectName + cmdName + slotId` 下不同参数快照的去重结果，可用于回看历史入参，也可从对应调用创建参数快照断点；相关调用在窄面板中采用记录卡片展示，避免多列表格文本重叠。
7. 从已发现接口创建命令断点，或从调用记录创建命令断点 / 参数快照断点；“调用记录”页右侧详情底部展示当前 Session 的断点列表，支持启用、禁用和删除；“断点管理”页按 `objectName` 可折叠分组展示启用状态、命中范围、来源和命中记录，卡片右侧保留固定操作区，命中记录同样采用窄栏卡片展示。
8. 按钮采用扁平化浅色背景和轻边框；JSON 查看区提供标题栏、内边距和自动换行，便于查看长字段；右侧详情附页隐藏滚动条，避免遮挡文字，仍可通过鼠标滚轮或触控板滚动内容。
9. 再次触发同一业务接口，命中断点后调用状态应变为 `paused`，顶部会出现暂停提示条。
10. 点击“继续执行”或“继续全部”后 Java 请求恢复，状态最终变为 `finished`。
11. 点击“停止调试”后，再触发 Java 接口不会新增调用记录；再次开始同一 Session 时会继续追加数据。

## 验证命令

```powershell
cd python-debugger
conda run -n micro-breakpoint pytest

cd ..\java-demo
mvn test
```
