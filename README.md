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

桌面端启动时会自动拉起 Python 后端；如果 `18601` 端口已经有后端在运行，桌面端会直接复用现有后端。
通过控制台运行 `python run_desktop.py` 时，会输出内置 Python 后端的启动、复用、停止日志，并保留 Flask 访问日志，便于排查接口请求。
退出桌面端时会先调用 `/api/debug/stop`，释放暂停中的断点请求并把当前 Session 写回空闲状态；如果复用了外部后端，只停止调试状态，不关闭外部后端进程。

启动 Java Demo：

```powershell
cd java-demo
mvn spring-boot:run
```

批量调用 Java Demo 的全部 REST 接口，生成多仪表对象和多样本值的调试流量：

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

## Session 归档与接口锁定

`.mbrec` 是 MicroBreakpoint 的 Session 归档文件。历史会话页可以导出当前 Session，并在导出时填写归档名称和备注；导入 `.mbrec` 会创建一个新的本地 Session，不会合并到当前 Session，也不会覆盖原有历史。首次导入前后端会先停止当前调试并释放所有真实 paused 调用，导入完成后自动打开新导入的 Session；归档里的历史 paused 调用会作为 `imported_paused` 保存，只用于回看，不会进入当前暂停计数，也不能继续执行。

`archiveId` 是后端保存的逻辑归档 ID，首次导出时如果当前 Session 还没有 `archive_id` 会自动生成并写回数据库；之后即使修改归档名称、备注或保存文件名，再次导出也会复用同一个 `archiveId`。同一个 `archiveId` 只允许导入一次；重复导入会先返回已有 Session ID 和打开入口，不会停止当前调试、释放 paused 调用或切换当前 Session。导入时可以勾选“导入后锁定接口”，主页状态栏也常驻“锁定接口”开关。

历史会话列表优先显示 `display_name`，导入 `.mbrec` 时会保存导入文件名，并默认把去掉 `.mbrec` 后缀的文件名作为显示名；本地新建 Session 会自动命名为“未命名 1 / 未命名 2 / ...”。SessionId 仅作为技术信息显示在副标题小字中。

锁定接口只阻止自动新增“已发现接口”。调用记录仍会保存，断点判断和暂停逻辑不受影响；锁定期间遇到的新接口调用会在调用记录中标记为“未登记”，用户可以从调用详情手动加入已发现接口。手动加入时会批量关联同一 Session 下相同 `objectName + cmdName` 的未登记调用，并重新计算该接口统计。

已发现接口唯一性固定为 `sessionId + objectName + cmdName`。`serviceName` 只是展示字段，不参与唯一性校验；`slotId` 不再拆分接口，只作为调用记录、接口样本和样本级断点条件保存。Java Demo 对外业务接口仍使用 `instType` 参数，例如 `GET /api/demo/control?instType=VNA&cmdName=create&slotId=1`；Java 上报到 Python 断点程序时会转换为 `objectName / cmdName / slotId`，Python 后端、数据库、QML、断点条件和调用详情都使用 `objectName`。

从已发现接口创建断点时，断点条件只包含 `objectName + cmdName`，会命中该接口下所有 `slotId`；从调用记录或样本创建参数快照断点时，可以包含 `slotId`，用于精确命中某个槽位样本。

## 验收流程

1. 桌面端进入“历史会话”，点击“新建 Session”或选择已有 Session。
2. 点击“开始调试”。
3. 手动调用 Java Demo 的 `POST /api/demo/control` 或真实业务接口。
4. “调用记录”页应出现当前 Session 的调用记录，并按 `objectName` 可折叠分组展示；分组标题显示调用数、命中数、暂停数、异常数和平均耗时。主表默认只保留“序号 / 命令 / 槽位 / 参数摘要 / 状态 / 耗时 / 标记”七列，表格铺满分组宽度且默认不横向滚动；只有手动拖宽“命令 / 参数摘要 / 标记”导致总列宽超过可视宽度时才显示横向滚动条。“线程名”“调用时间”“接口登记”和“断点命中”在右侧详情查看。
5. “已发现接口”页应按 `objectName` 可折叠分组展示接口、参数样本数、唯一键、断点状态和整数平均耗时；接口卡片采用“主信息 / 指标网格 / 固定操作列”的三列布局，操作按钮统一对齐。
6. “已发现接口”右侧详情可查看同一接口的不同参数样本。参数样本按同一 `objectName + cmdName` 下的 `slotId + params` 去重，可用于回看历史入参，也可从对应调用创建参数快照断点；相关调用在窄面板中采用记录卡片展示，避免多列表格文本重叠。
7. 从已发现接口创建命令断点，或从调用记录创建命令断点 / 参数快照断点；“调用记录”页右侧详情底部展示当前 Session 的断点列表，支持启用、禁用和删除；“断点管理”页按 `objectName` 可折叠分组展示启用状态、命中范围、来源和命中记录，卡片右侧保留固定操作区，匹配条件支持展开/收起查看完整参数，命中记录同样采用窄栏卡片展示。

## 手工验证脚本

仓库提供两个 bash 脚本用于验证新的接口唯一性和断点语义，默认 Python 后端为 `http://127.0.0.1:18601`，Java Demo 为 `http://127.0.0.1:8080`：

```bash
bash scripts/test_object_cmd_discovery.sh
bash scripts/test_object_cmd_breakpoint.sh
```

脚本会覆盖：相同 `instType + cmdName` 不同 `slotId` 在 Python 中归并为一条 `objectName + cmdName` 接口；相同 `objectName` 不同 `cmdName` 拆分为不同接口；不同 `objectName` 相同 `cmdName` 拆分为不同接口；接口级断点命中同一 `objectName + cmdName` 下所有 `slotId`；样本级断点只命中指定 `slotId`。
8. 按钮采用扁平化浅色背景和轻边框；JSON 查看区提供标题栏、内边距和自动换行，便于查看长字段；右侧详情附页隐藏滚动条，避免遮挡文字，仍可通过鼠标滚轮或触控板滚动内容。
9. 底部日志栏会显示最近一次桌面操作的返回摘要，点击“展开”可查看完整 JSON 日志。
10. 清空当前记录、清空历史、删除会话和删除断点都会先弹出确认框；确认后才执行删除，其中“清空历史”会删除全部 Session 及其调用记录、已发现接口和断点。
11. 再次触发同一业务接口，命中断点后调用状态应变为 `paused`，顶部会出现暂停提示条。
12. 点击“继续单个 / 继续执行”或“继续全部”后 Java 请求恢复，状态最终变为 `finished`。
13. 点击“停止调试”后，再触发 Java 接口不会新增调用记录；再次开始同一 Session 时会继续追加数据。

## 验证命令

```powershell
cd python-debugger
conda run -n micro-breakpoint pytest

cd ..\java-demo
mvn test
```
