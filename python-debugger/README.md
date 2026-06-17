# Python Debugger

## Java 后端迁移说明

当前后端端口仍为 `18601`。本目录继续提供 PySide6/QML 桌面端；`python run_desktop.py` 默认使用 `internal` 模式，在当前桌面进程内直接创建本项目自带的 Python Flask 后端。需要使用 Java jar 或外部调试后端时，通过启动参数显式选择。
桌面端通过 `--backend jar` 拉起 Java 后端时会传入当前桌面进程 PID；Java 后端会启用父进程 watchdog，检测到桌面进程异常退出后会先停止调试状态，再主动退出。手动启动或外部复用的 Java 后端不会带该 PID，因此不会被桌面端误停。

常用命令：

```powershell
python run_desktop.py
python run_desktop.py --backend jar
python run_desktop.py --backend external
```

断点后端端口 `18601`，桌面端使用 PySide6/QML。

## Conda 环境

```powershell
conda env create -f ..\environment.yml
conda activate micro-breakpoint
```

## 手动启动 Java 后端

```powershell
java -jar .\backend\micro-breakpoint-debugger.jar
```

## 启动桌面端

```powershell
python run_desktop.py
```

桌面端默认使用 `internal` 后端模式，会在当前桌面进程内直接创建本项目自带的 Python Flask 后端。若 `18601` 端口已有可用后端，桌面端会直接复用。

桌面端“设置”页可配置被调试业务服务的 IP/Host、端口、断点启用接口和请求超时；配置自动保存到应用目录下的 `data/settings.json`。内置 Python Flask 后端和 `--backend jar` 拉起的 Java 后端都会读取这份配置，在“开始调试 / 停止调试”时打开或关闭业务服务断点开关；业务服务不在线时，“开始调试”会失败并保持未调试状态。

显式使用本地 jar：

```powershell
python run_desktop.py --backend jar
```

`--backend jar` 会优先查找应用目录下的 `backend/micro-breakpoint-debugger.jar`，否则允许唯一一个 `backend/micro-breakpoint-debugger-*.jar`。源码运行时应用目录为 `python-debugger`，打包后为 exe 所在目录。也可以用 `--backend-jar <path>` 指定 jar，或用 `--backend-dir <dir>` 指定查找目录。找不到 jar 时会直接报错，不会调用 Maven 或尝试编译。

使用外部后端或先打开桌面端再手动调试后端：

```powershell
python run_desktop.py --backend external
```

`external` 不启动后端、不检查后端，也不管理后端关闭；后端未启动时，请求失败会按现有界面错误提示显示。退出桌面端时，`internal` 和 `jar` 会先调用 `/api/debug/stop` 释放暂停请求，并关闭桌面端自己启动的后端；`external` 不会触碰外部进程。

## PyInstaller 打包

```powershell
cd python-debugger
conda run -n micro-breakpoint python -m PyInstaller MicroBreakpoint.spec
```

产物位于 `python-debugger/dist/MicroBreakpoint`。默认 `internal` 后端使用应用目录下的 `data/debugger.sqlite3`；`jar` 后端会使用同一个数据库路径，并默认查找应用目录下的 `backend/`。如果已先执行 `mvn -DskipTests package`，且 `python-debugger/backend` 不存在，spec 会把 `java-debugger/target/micro-breakpoint-debugger-0.1.0.jar` 收进打包产物的 `backend/` 目录。

## 主题与外观

桌面端支持暗色模式和亮色模式。可以通过顶部标题栏右侧的主题按钮快速切换。

主题选择会持久化保存，重启桌面端后保持上次选择。默认主题为暗色。

## 调试服务配置

左侧“设置”页会自动保存被调试业务服务的断点开关配置。源码运行时配置文件为 `python-debugger/data/settings.json`，打包后为 exe 所在目录下的 `data/settings.json`。

```json
{
  "themeMode": "dark",
  "debugTarget": {
    "host": "127.0.0.1",
    "port": 8080,
    "debuggerSwitchPath": "/api/demo/debugger/enabled",
    "requestTimeoutMs": 1000
  }
}
```

`internal` 后端会直接读取该文件；`--backend jar` 会把同一文件路径传给 Java 后端。手动启动外部 Java 后端时，可添加 `-Dmicro-breakpoint.settings-file=<settings.json 路径>` 使用同一份配置。

## Session 归档与锁定接口

`.mbrec` 文件用于归档单个组件化断点调试工具会话。桌面端历史会话页支持导出归档名称和备注，首次导入时会先停止当前调试、释放真实 paused 调用，再创建并打开一个新的本地会话；导入不会合并到当前会话。归档中的 paused 调用导入后会显示为 `imported_paused`，表示“历史暂停”，不进入当前暂停计数，也不能继续执行。

后端通过 `archiveId` 防止重复导入。重复导入会先返回已有 Session ID，桌面端可打开该会话，但不会停止当前调试、释放 paused 调用或修改当前会话。导入时可选择导入后锁定接口，主页也提供常驻锁定接口开关。锁定接口只阻止新接口自动加入“接口列表”，不会影响调用记录保存、断点判断或暂停逻辑；未登记调用会在调用记录中标记，并可手动批量加入接口列表。

## 接口发现规则

接口列表唯一性为 `sessionId + objectName + cmdName`。`serviceName` 仅作为普通字段展示，`slotId` 作为调用记录、样本和条件断点条件保存，不参与接口唯一性。Java Demo 对外请求仍可使用 `instType`，但 Java 上报 Python 时会转换为 `objectName / cmdName / slotId`，Python 后端和 QML 页面不把 `instType` 当作内部字段。

从接口列表创建命令断点时只包含 `objectName + cmdName`，会命中该接口下所有 `slotId`；从调用记录或样本创建条件断点时使用 `slot_key` 和参数指纹或条件表达式，用于命中指定槽位样本。命令断点按 `session_id + object_name + cmd_name` 去重，条件断点按 `session_id + object_name + cmd_name + slot_key + match_mode` 继续比较参数指纹或规范化后的条件 JSON。

## 大 Payload 机制

后端完整接收 Java 上报的 `params/result`，但列表、日志和 QML 主模型只返回摘要字段。`/api/calls` 使用 SQL 级过滤、排序和分页，默认 `pageSize=50`，仅包含调用身份、状态、耗时、断点、`paramsSummary/resultSummary`、大小和截断标识，不返回完整 JSON。`/api/interfaces` 同样使用 SQL 级分页；`/api/calls/grouped` 和 `/api/interfaces/grouped` 使用全量 SQL 聚合统计整个 Session。

完整 payload 进入 `call_payloads`：不超过 64KB 的内容保存在 `content_text`，超过 64KB 的内容写入 `data/payloads/{session_id}/{bucket}/{call_id}/params.json` 或 `result.json`。详情页默认显示 preview；调用详情使用 `/api/calls/{callId}/payload`、`/api/calls/{callId}/payload/export`、`/api/calls/{callId}/payload/search`，接口样本和断点快照等独立样本使用 `/api/payloads/{payloadId}`、`/api/payloads/{payloadId}/export`、`/api/payloads/{payloadId}/search?q=...`。文件型 payload 搜索按 1MB 分块流式扫描，不一次性读取完整大文件。

桌面端 Payload 预览区支持横向和纵向滚动，长 JSON 不会撑进调用列表或日志；后端会生成结构化裁剪后的合法 JSON preview，大字符串会替换为短摘要加省略号，大对象只展示前几个键值并标记总键数、展示数和省略数，避免直接截断字符串导致无法格式化。`LargePayloadViewer` 支持 `callId+type` 和 `payloadId` 两种来源，“加载全部”会从 offset 0 拼接完整内容到界面，只有 preview 覆盖完整 payload 时才显示已加载全部，大文件建议导出查看；搜索框独立成行，结果在预览区内联显示。

`.mbrec` 桌面导入导出使用 zip 格式：`db.json` 保存数据库记录和 payload 元信息，大 payload 作为 `payloads/...` zip entry 单独存放；导入时校验大小和 hash，并恢复到新 Session 的 payload 目录。旧 JSON 归档接口保留兼容，但不会把文件型大 payload 内联进 JSON。

参数样本按 `interface_id + slot_key + params_hash` 去重，样本列表和断点页只展示摘要、preview、大小、hash、payloadId 和命中次数；接口样本通过 `paramsPayloadId` 读取 JSON，不依赖 `callId`。`params_json/result_json/latest_params_json/params_snapshot_json/condition_json` 均为 legacy 兼容字段，新代码不再写入完整大 JSON，列表 API 和 QML 列表不得绑定这些字段。

## 验收主链路

1. 启动 Java Demo。
2. 打开桌面端，默认进入“接口列表”，点击“新建会话”。
3. 点击“开始调试”。
4. 通过脚本、接口工具或真实业务流量触发 Java Demo 接口。
5. 在“调用记录”和“接口列表”中查看当前 Session 的动态记录；调用记录表格按 `objectName` 分组并铺满分组宽度，默认八列为“序号 / 命令 / 槽位 / 参数摘要 / 状态 / 耗时 / 断点 / 接口”，断点命中和接口登记状态分别独立展示。“线程名”“调用时间”等长字段在右侧详情以 Tab 和信息卡片展示。接口样本页使用带滚动条的横向样本选择和整宽 Payload 查看区，调用详情右侧面板保留更宽的分段 Tab 栏和网格按钮操作区。
6. 从接口列表创建命令断点，或从调用记录创建命令断点 / 条件断点；接口详情概览会展示当前接口按业务属性关联的断点，并支持启用、禁用和删除。
7. 再次触发同一业务接口，调用状态应变为 `paused`，顶部暂停提示条和暂停行高亮应同时出现。
8. 点击“继续执行”或“继续全部”后 Java 请求恢复，状态变为 `finished`。
9. 点击“停止调试”后，新的 Java before-call 会直接放行并且不会新增调试数据。

注意：记录模式已经移除。Python 后端的新接口为 `/api/sessions`、`/api/debug/start`、`/api/debug/stop` 和 `/api/debug/reset`；桌面端不再提供 Java 调用页，Java 请求应由外部脚本、接口工具或真实业务系统触发。
