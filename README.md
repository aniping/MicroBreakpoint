# 组件化断点调试工具

组件化断点调试工具是一个面向业务组件命令的接口级断点调试 Demo。它由两部分组成：

- `java-demo/`：Spring Boot 3 微服务示例，提供仪表初始化和控制接口，并通过 AOP 上报调用。
- `python-debugger/`：PySide6/QML 桌面端 + legacy Flask 代码，用于 Session 化采集调用、动态发现接口、设置断点并控制 Java 请求继续执行。

关键原则：当前模型只有“开始调试 / 停止调试”。点击“开始调试”后，Java 上报的 before-call 才会进入调用记录、接口发现和断点判断；停止调试后新的 before-call 会直接放行，不污染当前 Session。Java 调用由外部脚本、业务系统或手动 HTTP 请求触发，桌面端不再承担 Java 请求发起器职责。

Java Demo 默认以 `debugger.enabled=false` 启动。点击“开始调试”时，Java 后端会先按 `micro-breakpoint.demo-base-url` 请求 Demo 的 `/api/demo/debugger/enabled` 打开上报开关；如果 Demo 不在线或请求失败，桌面端会弹窗提示并保持未调试状态。点击“停止调试”会释放后端暂停请求并关闭 Demo 开关；如果断点后端异常退出，Demo 下次上报失败时也会自动把本地开关关闭。

用户操作和 Java 侵入式接入说明见：[用户指导手册](docs/user-guide.md)。

## 环境

Python 使用 conda 环境管理：

```powershell
conda env create -f environment.yml
conda activate micro-breakpoint
```

Java 需要 JDK 17+ 和 Maven，Demo 代码不依赖 IDE Lombok 插件或额外注解处理配置。

## 启动

启动桌面端：

```powershell
cd python-debugger
python run_desktop.py
```

桌面端默认使用 `external` 后端模式：不会自动启动后端，也不会编译后端；启动前只检查 `http://127.0.0.1:18601/api/debug/state` 是否可用。需要先手动启动后端，或改用下面的显式模式。

使用当前运行目录下 `backend/` 文件夹中的 jar 作为后端：

```powershell
cd python-debugger
python run_desktop.py --backend jar
```

`--backend jar` 会优先查找 `backend/micro-breakpoint-debugger.jar`，否则允许唯一一个 `backend/micro-breakpoint-debugger-*.jar`。也可以用 `--backend-jar <path>` 指定 jar，或用 `--backend-dir <dir>` 指定查找目录。找不到 jar 时会直接报错，不会调用 Maven 或尝试编译。

只打开桌面端、不检查后端：

```powershell
cd python-debugger
python run_desktop.py --backend none
```

`none` 适合先打开 UI、再手动调试后端 jar 的场景；后端未启动时，请求失败会按现有界面错误提示显示。退出桌面端时，`external` 和 `jar` 会先调用 `/api/debug/stop` 释放暂停请求；只有 `jar` 模式会关闭桌面端自己启动的后端进程，`external` 不会关闭外部进程，`none` 不管理后端运行时。

启动 Java Demo：

```powershell
cd java-demo
mvn spring-boot:run
```

批量调用 Java Demo 的全部 REST 接口，生成多仪表对象、多样本值和大文本 payload 的调试流量：

```powershell
cd java-demo
.\scripts\call-all-demo-apis.ps1
```

推荐开发验证顺序：

1. 先启动后端，再打开桌面端并确认后端可用。
2. 启动 Java Demo。
3. 在桌面端创建或打开 Session，再点击“开始调试”。
4. 通过脚本、接口工具或真实业务流量触发 Java Demo 接口。

## 界面主题

桌面端支持暗色模式和亮色模式。顶部标题栏右侧的主题按钮可快速切换亮暗主题。

主题选择会通过桌面端配置持久化，退出并重新启动后会保持上次选择。默认主题为暗色。

主题系统集中管理窗口背景、顶部栏、工具栏、侧边栏、面板、文字、输入框、状态标签和 JSON 查看区域的颜色，避免各页面散落大面积硬编码颜色。

## Session 归档与接口锁定

`.mbrec` 是组件化断点调试工具的会话归档文件。历史会话页可以导出当前会话，并在导出时填写归档名称和备注；导入 `.mbrec` 会创建一个新的本地会话，不会合并到当前会话，也不会覆盖原有历史。首次导入前后端会先停止当前调试并释放所有真实 paused 调用，导入完成后自动打开新导入的会话；归档里的历史 paused 调用会作为 `imported_paused` 保存，只用于回看，不会进入当前暂停计数，也不能继续执行。

`archiveId` 是后端保存的逻辑归档 ID，首次导出时如果当前 Session 还没有 `archive_id` 会自动生成并写回数据库；之后即使修改归档名称、备注或保存文件名，再次导出也会复用同一个 `archiveId`。同一个 `archiveId` 只允许导入一次；重复导入会先返回已有 Session ID 和打开入口，不会停止当前调试、释放 paused 调用或切换当前 Session。导入时可以勾选“导入后锁定接口”，主页状态栏也常驻“锁定接口”开关。

历史会话列表优先显示 `display_name`，导入 `.mbrec` 时会保存导入文件名，并默认把去掉 `.mbrec` 后缀的文件名作为显示名；本地新建会话会自动命名为“未命名 1 / 未命名 2 / ...”。SessionId 仅作为技术信息显示在副标题小字中。

锁定接口只阻止自动新增“接口列表”。调用记录仍会保存，断点判断和暂停逻辑不受影响；锁定期间遇到的新接口调用会在调用记录中标记为“未登记”，用户可以从调用详情手动加入接口列表。手动加入时会批量关联同一 Session 下相同 `objectName + cmdName` 的未登记调用，并重新计算该接口统计。

接口列表唯一性固定为 `sessionId + objectName + cmdName`。`serviceName` 只是展示字段，不参与唯一性校验；`slotId` 不再拆分接口，只作为调用记录、接口样本和条件断点条件保存。Java Demo 对外业务接口仍使用 `instType` 参数，例如 `GET /api/demo/control?instType=VNA&cmdName=create&slotId=1`；Java 上报到 Python 断点程序时会转换为 `objectName / cmdName / slotId`，Python 后端、数据库、QML、断点条件和调用详情都使用 `objectName`。

从接口列表创建命令断点时，断点条件只包含 `objectName + cmdName`，会命中该接口下所有 `slotId`；从调用记录或样本创建条件断点时，会使用规范化后的 `slot_key` 和参数指纹或条件表达式，用于精确命中某个槽位样本。

断点唯一性以业务属性为准：命令断点按 `session_id + object_name + cmd_name + match_mode` 去重；条件断点按 `session_id + object_name + cmd_name + slot_key + match_mode` 继续比较 `params_fingerprint` 或规范化后的 `conditions_json`。`method_name`、`class_name`、`service_name` 只作为 Java 上报辅助信息保存和展示。

## 大 Payload 存储与查看

Java 侧仍可完整上报 `params` 和 `result`，Python 后端会完整接收并保存，但列表、日志和 QML 主模型只进入轻量摘要链路。`call_record` 只保留 `params_summary/result_summary`、前 8KB `preview`、大小、hash、截断标识和 payload 引用；`/api/calls` 使用 SQL 级过滤、排序和分页，默认只返回 50 条轻量调用记录，可通过 `pageSize=20/50/100` 分页浏览，不返回完整 `params/result/rawArgs`。`/api/interfaces` 同样使用 SQL 级分页，避免把整个 Session 的接口记录加载到 Python 内存。

完整内容保存在 `call_payloads`：小于等于 64KB 的 payload 内联到 `content_text`，大于 64KB 的 payload 写入 `python-debugger/data/payloads/{session_id}/{bucket}/{call_id}/{params|result}.json`，SQLite 只保存路径、大小、hash 和编码信息。调用详情通过 `/api/calls/{callId}/payload?type=params|result` 分块读取、导出和搜索；接口样本、断点快照等没有稳定 `callId` 的场景通过 `/api/payloads/{payloadId}`、`/api/payloads/{payloadId}/export`、`/api/payloads/{payloadId}/search?q=...` 读取同一份 payload。文件型 payload 搜索按 1MB 分块流式扫描并保留跨块 overlap，不会一次性读取完整大文件。

桌面端 Payload 预览区支持横向和纵向滚动，长 JSON 不会撑进调用列表或日志；后端会生成结构化裁剪后的合法 JSON preview，大字符串会替换为短摘要加省略号，大对象只展示前几个键值并标记总键数、展示数和省略数，避免直接截断字符串导致无法格式化。`LargePayloadViewer` 同时支持 `callId+type` 和 `payloadId` 两种读取来源，“加载全部”会从 offset 0 拼接完整内容到界面，只有 preview 覆盖完整 payload 时才显示已加载全部，大文件建议直接导出查看。搜索框独立成行并只触发后端完整 payload 搜索，结果在预览区内联显示。

`/api/calls/grouped` 和 `/api/interfaces/grouped` 使用全量 SQL 聚合统计整个 Session，不依赖列表第一页。`.mbrec` 桌面导入导出使用 zip 格式：`db.json` 保存数据库记录和 payload 元信息，大 payload 作为 `payloads/...` zip entry 单独存放；导入时会校验大小和 hash，并把 payload 文件恢复到新 Session 的 payload 目录。旧 JSON 归档接口仍保留兼容，但不会把文件型大 payload 内联到 JSON。

接口参数样本按 `interface_id + slot_key + params_hash` 去重，只保存摘要、preview、大小、hash、payload 引用、截断标识、样本次数和首末次时间；已发现接口页通过 `paramsPayloadId` 读取参数样本，不依赖 `callId` join。`call_record.params_json/result_json`、`discovered_interface.latest_params_json`、`interface_param_sample.params_json/result_json`、`breakpoint.params_snapshot_json`、`breakpoint.condition_json` 是 legacy 字段，仅为历史数据兼容保留，新代码不再写入完整大 JSON，也不得在列表接口或 QML 列表中绑定。

## 验收流程

1. 桌面端默认进入“接口列表”，点击“新建会话”或在“历史会话”选择已有会话。
2. 点击“开始调试”。
3. 手动调用 Java Demo 的 `POST /api/demo/control` 或真实业务接口。
4. “调用记录”页应出现当前 Session 的调用记录，并按 `objectName` 可折叠分组展示；分组标题显示调用数、命中数、暂停数、异常数和平均耗时。主表默认只保留“序号 / 命令 / 槽位 / 参数摘要 / 状态 / 耗时 / 断点 / 接口”八列，表格铺满分组宽度且默认不横向滚动；只有手动拖宽“命令 / 参数摘要”导致总列宽超过可视宽度时才显示横向滚动条。“线程名”“调用时间”等长字段在右侧详情查看。
5. “接口列表”页应按 `objectName` 可折叠分组展示接口、参数样本数、唯一键、断点状态和整数平均耗时；接口卡片采用“主信息 / 指标网格 / 固定操作列”的三列布局，操作按钮统一对齐。
6. “接口列表”右侧详情可查看同一接口的不同参数样本，并在“概览 / 断点信息”中展示当前接口按 `session_id + object_name + cmd_name` 关联的断点，支持启用、禁用和删除。参数样本按同一 `objectName + cmdName` 下的 `slotId + params` 去重，可用于回看历史入参，也可从对应调用创建条件断点。
7. 从接口列表创建命令断点，或从调用记录创建命令断点 / 条件断点；“调用记录”页右侧详情底部展示当前 Session 的断点列表，支持启用、禁用和删除；“断点列表”页按 `objectName` 可折叠分组展示启用状态、命中范围、来源和命中记录，卡片右侧保留固定操作区，匹配条件支持展开/收起查看完整参数，命中记录同样采用窄栏卡片展示。

## 手工验证脚本

仓库提供两个 bash 脚本用于验证新的接口唯一性和断点语义，默认断点后端为 `http://127.0.0.1:18601`，Java Demo 为 `http://127.0.0.1:8080`：

```bash
bash scripts/test_object_cmd_discovery.sh
bash scripts/test_object_cmd_breakpoint.sh
```

脚本会覆盖：相同 `instType + cmdName` 不同 `slotId` 在 Python 中归并为一条 `objectName + cmdName` 接口；相同 `objectName` 不同 `cmdName` 拆分为不同接口；不同 `objectName` 相同 `cmdName` 拆分为不同接口；接口级断点命中同一 `objectName + cmdName` 下所有 `slotId`；样本级断点只命中指定 `slotId`。
8. 按钮采用扁平化浅色背景和轻边框；接口样本页使用带滚动条的横向样本选择和整宽 Payload 查看区；调用详情右侧面板保留更宽的分段 Tab 栏和网格按钮操作区；JSON 查看区提供标题栏、内边距和自动换行，便于查看长字段；右侧详情附页隐藏滚动条，避免遮挡文字，仍可通过鼠标滚轮或触控板滚动内容。
9. 底部日志栏会显示最近一次桌面操作的返回摘要，点击“展开”可查看完整 JSON 日志。
10. 清空当前、清空历史、删除会话和删除断点都会先弹出确认框；确认后才执行删除，其中“清空当前”会删除当前会话的接口、调用记录、参数样本和相关断点，“清空历史”会删除全部会话及其调用记录、接口和断点。
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
## Java 后端

后端已迁移为 `java-debugger/` Spring Boot 服务，默认监听 `http://127.0.0.1:18601`，继续使用现有 SQLite 数据库与 payload 目录。`python-debugger/` 仍保留 PySide6/QML 桌面端和 legacy Flask 代码；桌面端默认使用外部后端，不再自动拉起 `java-debugger` 或 Maven。

Java 后端默认通过 `micro-breakpoint.demo-base-url=http://127.0.0.1:8080` 联动 Java Demo 调试开关，请求超时由 `micro-breakpoint.demo-request-timeout-ms` 控制。
桌面端通过 `--backend jar` 拉起 Java 后端时会传入父进程 PID；Java 后端 watchdog 检测到桌面端异常退出后会先停止调试状态，再主动退出。手动启动或外部复用的 Java 后端不会带该 PID，不会被桌面端误停。

启动 Java 后端：

```powershell
java -jar .\backend\micro-breakpoint-debugger.jar
```

打包后端：

```powershell
cd java-debugger
mvn -DskipTests package
```

验证命令：

```powershell
cd java-debugger
mvn test

cd ..\python-debugger
conda run -n micro-breakpoint pytest tests/test_desktop_backend_runtime.py tests/test_java_demo_scripts.py
```
