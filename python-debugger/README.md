# Python Debugger

Flask 后端端口 `18601`，桌面端使用 PySide6/QML。

## Conda 环境

```powershell
conda env create -f ..\environment.yml
conda activate micro-breakpoint
```

## 启动后端

```powershell
python run_backend.py
```

## 启动桌面端

```powershell
python run_desktop.py
```

桌面端会自动拉起 Flask 后端；`run_backend.py` 仍保留给后端单独启动和调试使用。若 `http://127.0.0.1:18601` 已经可用，桌面端会复用该后端。
通过控制台运行 `python run_desktop.py` 时，会输出内置后端启动、复用、停止日志，并保留 Flask 访问日志，便于排查接口请求。
退出桌面端时会先调用 `/api/debug/stop`，释放暂停中的断点请求并把当前会话写回空闲状态；下次启动会恢复上次打开的会话，但默认仍进入“接口列表”页。如果复用了外部后端，只停止调试状态，不关闭外部后端进程。

## 主题与外观

桌面端支持暗色模式和亮色模式。可以通过顶部标题栏右侧的主题按钮快速切换。

主题选择会持久化保存，重启桌面端后保持上次选择。默认主题为暗色。

## Session 归档与锁定接口

`.mbrec` 文件用于归档单个组件化断点调试工具会话。桌面端历史会话页支持导出归档名称和备注，首次导入时会先停止当前调试、释放真实 paused 调用，再创建并打开一个新的本地会话；导入不会合并到当前会话。归档中的 paused 调用导入后会显示为 `imported_paused`，表示“历史暂停”，不进入当前暂停计数，也不能继续执行。

后端通过 `archiveId` 防止重复导入。重复导入会先返回已有 Session ID，桌面端可打开该会话，但不会停止当前调试、释放 paused 调用或修改当前会话。导入时可选择导入后锁定接口，主页也提供常驻锁定接口开关。锁定接口只阻止新接口自动加入“接口列表”，不会影响调用记录保存、断点判断或暂停逻辑；未登记调用会在调用记录中标记，并可手动批量加入接口列表。

## 接口发现规则

接口列表唯一性为 `sessionId + objectName + cmdName`。`serviceName` 仅作为普通字段展示，`slotId` 作为调用记录、样本和条件断点条件保存，不参与接口唯一性。Java Demo 对外请求仍可使用 `instType`，但 Java 上报 Python 时会转换为 `objectName / cmdName / slotId`，Python 后端和 QML 页面不把 `instType` 当作内部字段。

从接口列表创建命令断点时只包含 `objectName + cmdName`，会命中该接口下所有 `slotId`；从调用记录或样本创建条件断点时使用 `slot_key` 和参数指纹或条件表达式，用于命中指定槽位样本。命令断点按 `session_id + object_name + cmd_name` 去重，条件断点按 `session_id + object_name + cmd_name + slot_key + match_mode` 继续比较参数指纹或规范化后的条件 JSON。

## 大 Payload 机制

后端完整接收 Java 上报的 `params/result`，但列表、日志和 QML 主模型只返回摘要字段。`/api/calls` 使用 SQL 级过滤、排序和分页，默认 `pageSize=50`，仅包含调用身份、状态、耗时、断点、`paramsSummary/resultSummary`、大小和截断标识，不返回完整 JSON。`/api/interfaces` 同样使用 SQL 级分页；`/api/calls/grouped` 和 `/api/interfaces/grouped` 使用全量 SQL 聚合统计整个 Session。

完整 payload 进入 `call_payloads`：不超过 64KB 的内容保存在 `content_text`，超过 64KB 的内容写入 `data/payloads/{session_id}/{bucket}/{call_id}/params.json` 或 `result.json`。详情页默认显示 preview；调用详情使用 `/api/calls/{callId}/payload`、`/api/calls/{callId}/payload/export`、`/api/calls/{callId}/payload/search`，接口样本和断点快照等独立样本使用 `/api/payloads/{payloadId}`、`/api/payloads/{payloadId}/export`、`/api/payloads/{payloadId}/search?q=...`。文件型 payload 搜索按 1MB 分块流式扫描，不一次性读取完整大文件。

桌面端 Payload 预览区支持横向和纵向滚动，长 JSON 不会撑进调用列表或日志；后端会生成结构化裁剪后的合法 JSON preview，避免直接截断字符串导致无法格式化。`LargePayloadViewer` 支持 `callId+type` 和 `payloadId` 两种来源，“加载全部”会从 offset 0 拼接完整内容到界面，大文件建议导出查看；搜索结果使用浮层显示，不占用 JSON 展示区高度。

`.mbrec` 桌面导入导出使用 zip 格式：`db.json` 保存数据库记录和 payload 元信息，大 payload 作为 `payloads/...` zip entry 单独存放；导入时校验大小和 hash，并恢复到新 Session 的 payload 目录。旧 JSON 归档接口保留兼容，但不会把文件型大 payload 内联进 JSON。

参数样本按 `interface_id + slot_key + params_hash` 去重，样本列表和断点页只展示摘要、preview、大小、hash、payloadId 和命中次数；接口样本通过 `paramsPayloadId` 读取 JSON，不依赖 `callId`。`params_json/result_json/latest_params_json/params_snapshot_json/condition_json` 均为 legacy 兼容字段，新代码不再写入完整大 JSON，列表 API 和 QML 列表不得绑定这些字段。

## 验收主链路

1. 启动 Java Demo。
2. 打开桌面端，默认进入“接口列表”，点击“新建会话”。
3. 点击“开始调试”。
4. 通过脚本、接口工具或真实业务流量触发 Java Demo 接口。
5. 在“调用记录”和“接口列表”中查看当前 Session 的动态记录；调用记录表格按 `objectName` 分组并铺满分组宽度，默认八列为“序号 / 命令 / 槽位 / 参数摘要 / 状态 / 耗时 / 断点 / 接口”，断点命中和接口登记状态分别独立展示。“线程名”“调用时间”等长字段在右侧详情以 Tab 和信息卡片展示。
6. 从接口列表创建命令断点，或从调用记录创建命令断点 / 条件断点；接口详情概览会展示当前接口按业务属性关联的断点，并支持启用、禁用和删除。
7. 再次触发同一业务接口，调用状态应变为 `paused`，顶部暂停提示条和暂停行高亮应同时出现。
8. 点击“继续执行”或“继续全部”后 Java 请求恢复，状态变为 `finished`。
9. 点击“停止调试”后，新的 Java before-call 会直接放行并且不会新增调试数据。

注意：记录模式已经移除。Python 后端的新接口为 `/api/sessions`、`/api/debug/start`、`/api/debug/stop` 和 `/api/debug/reset`；桌面端不再提供 Java 调用页，Java 请求应由外部脚本、接口工具或真实业务系统触发。
