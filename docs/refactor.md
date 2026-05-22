# MicroBreakpoint 重构设计方案：Session 化接口断点调试器

> 目标读者：Codex / 开发者  
> 目标目录：`docs/`  
> 建议文件名：`docs/refactor-session-debugger-design.md`  
> 文档目的：指导 MicroBreakpoint 从“记录 + 调试”双模式，重构为“Session 化调试采集 + 接口发现 + 断点控制”的清晰模型。
> 注意事项：`docs/v1` 是旧文档，是构前的项目信息

---

## 1. 重构背景

当前 MicroBreakpoint 已经具备 Java 微服务接口上报、Python 后端记录、桌面端展示、断点暂停与继续等基础能力。

但现有设计中存在几个需要重构的问题：

1. “开始记录 / 停止记录”和“开始调试 / 停止调试”两套模式容易混淆。
2. Java 调用页面由调试器主动请求 Java Demo，产品定位不够纯粹。
3. 已发现接口主要围绕 Java 方法维度展示，和真实业务使用方式不够贴合。
4. `DebugMethodInfo` 中 `params` 目前不是顶层字段，不利于接口去重、调用记录展示和后续参数断点。
5. 调用记录、已发现接口、断点管理页面需要更强的业务分组、折叠、反馈和易用性。
6. 已发现接口需要按 Session 隔离，避免历史调试数据污染当前调试现场。

本次重构后的产品定位：

```text
MicroBreakpoint 是一个面向 Java 微服务的 Session 化接口断点调试器。

用户新建 Session 后，点击开始调试。
从开始调试那一刻起，Java 上报的接口调用会被记录、被发现、被用于断点判断。
停止调试后，系统不再接收新的 before-call 数据用于记录、发现接口和断点判断，并释放所有暂停中的 Java 调用。
同一个 Session 可以再次点击开始调试，后续调用继续追加到该 Session。
```

---

## 2. 核心设计结论

本次重构需要遵循以下结论：

```text
1. 删除“开始记录 / 停止记录”按钮及相关记录模式逻辑。
2. 使用“Session + 调试状态”作为新的核心工作模型。
3. 点击“开始调试”后，才开始记录调用、发现接口、判断断点。
4. 停止调试后，新的 before-call 不记录、不发现、不判断断点，并释放全部暂停调用。
5. Java 调用页面从主 UI 删除，改为开发脚本辅助测试。
6. DebugMethodInfo 中 params 提升为顶层一等字段。
7. args / parameterMeta 保留为可选技术信息，不参与主业务流程。
8. Session 隔离调用记录、已发现接口、接口统计和断点。
9. 已发现接口唯一键为：sessionId + objectName + cmdName + slotId。
10. params 不参与接口唯一键，但用于参数展示、参数样例、参数快照断点和未来参数条件断点。
11. 调用记录和已发现接口都按 objectName 折叠分组。
12. objectName 外层不做搜索排序；搜索、过滤、排序只在每个 objectName 分组内部进行。
13. 顶部按钮按 Session 管理、调试控制、执行控制、界面设置分区。
14. UI 反馈必须明显：大按钮、大图标、高亮暂停行、自动打开详情、状态栏强提示。
15. 不兼容旧 API 路径，按新项目直接替换接口契约。
```

---

## 3. 新工作流

### 3.1 正常调试流程

```text
1. 用户打开 MicroBreakpoint 桌面端。
2. 用户点击“新建 Session”，系统创建一个新的 debug session。
3. 用户点击“开始调试”，当前 Session 进入 Debugging 状态。
4. 用户手动调用 Java Demo 或真实业务微服务接口。
5. Java 微服务向 Python 后端上报 before-call。
6. Python 判断当前处于 Debugging：
   - 创建调用记录；
   - 发现或更新接口；
   - 判断是否命中断点。
7. 如果未命中断点：
   - Python 返回 continue；
   - Java 继续执行真实业务方法。
8. 如果命中断点：
   - Python 创建 wait event；
   - 调用记录状态变为 paused；
   - Python 返回 pause；
   - Java 请求阻塞等待；
   - UI 高亮展示 paused 调用。
9. 用户点击“继续执行”或“继续全部”。
10. Python 释放对应 wait event。
11. Java 恢复执行真实业务方法。
12. Java 上报 after-call。
13. Python 更新调用状态、耗时、返回值、异常信息和接口统计。
14. 用户点击“停止调试”。
15. Python 结束当前调试状态，释放所有暂停调用，Session 保留为历史数据。
```

### 3.2 非调试状态下 Java 上报处理

```text
如果 debugging = false：

before-call：
  - 不创建调用记录；
  - 不发现接口；
  - 不判断断点；
  - 直接返回 continue。

after-call：
  - 总是尝试按 callId 更新已存在的调用记录；
  - 如果找不到 callId 对应记录，直接忽略并返回 success。
```

这样可以避免非调试期间的业务调用污染调试数据。
如果某个调用在调试中创建，但停止调试后 after-call 才回来，仍然需要更新已有调用记录，避免遗留 running 状态。

---

## 4. 顶部按钮设计

顶部按钮采用分区布局：

```text
Session 区：
[新建 Session] [清空当前 Session]

调试区：
[开始调试] [停止调试] [重置调试状态]

执行控制区：
[继续执行] [继续全部]

界面区：
[主题切换]
```

推荐最终按钮文案：

```text
新建 Session
清空当前 Session
开始调试
停止调试
重置调试状态
继续执行
继续全部
主题切换
```

如果 UI 空间不足，可以缩短为：

```text
新建 Session
清空 Session
开始调试
停止调试
重置调试
继续执行
继续全部
主题切换
```

但内部代码和提示文案建议使用更清晰的完整语义。

---

## 5. 顶部按钮语义

### 5.1 新建 Session

作用：

```text
创建一个新的调试 Session。
新的调用记录和已发现接口都归属于这个 Session。
```

行为：

```text
如果当前没有调试中：
  直接创建新 Session。

如果当前正在调试中但没有 paused 调用：
  提示用户：当前正在调试，新建 Session 会停止当前调试，是否继续？

如果当前正在调试中且存在 paused 调用：
  提示用户：当前有暂停请求，新建 Session 会先全部放行并结束当前调试，是否继续？
```

要求：

```text
新建 Session 不删除历史 Session。
新建 Session 不删除历史 Session 中的断点。
新 Session 默认没有断点，除非用户在该 Session 内新建。
新建 Session 后，当前页面切换到新 Session。
```

---

### 5.2 清空当前 Session

作用：

```text
清空当前 Session 下的调用记录、已发现接口和统计信息。
```

不清空：

```text
不删除当前 Session 的断点。
不删除其他历史 Session。
不清空全局设置。
```

保留断点的前提是断点本身必须保存完整匹配字段：session_id、object_name、cmd_name、slot_key、match_mode、params_fingerprint/conditions_json。`source_*` 字段只用于追溯来源，即使来源调用或接口被清空，断点仍不能变成悬空不可用状态。

建议限制：

```text
调试中禁止清空当前 Session。
如需清空，必须先停止调试。
```

确认提示：

```text
将清空当前 Session 的调用记录和已发现接口，此操作不可恢复，是否继续？
```

---

### 5.3 开始调试

作用：

```text
让当前 Session 进入调试状态。
从此刻开始，Java 上报才会被记录、发现接口、判断断点。
```

行为：

```text
如果当前没有 Session：
  自动创建一个新 Session，然后进入调试状态。

如果当前已有 Session 且未调试：
  当前 Session 进入调试状态；如果该 Session 之前已经调试过，新调用继续追加到该 Session。

如果当前已经调试中：
  按钮不可用。
```

---

### 5.4 停止调试

作用：

```text
退出调试状态。
停止将新的 before-call 写入调用记录。
停止基于新的 before-call 发现接口。
停止基于新的 before-call 判断断点。
释放所有 paused 调用。
```

行为：

```text
如果没有 paused 调用：
  直接停止调试。

如果存在 paused 调用：
  提示用户：当前有 N 个请求暂停中，停止调试会全部继续执行，是否确认？
```

---

### 5.5 重置调试状态

原始需求中叫“清空调试”，但为了避免和“清空 Session”混淆，建议命名为：

```text
重置调试状态
```

作用：

```text
清理当前调试运行态，不删除 Session 数据。
```

包括：

```text
释放所有 paused 调用。
清空当前命中断点提示。
清空当前选中调用。
清空临时高亮状态。
重置 paused/running 等临时状态。
```

不包括：

```text
不删除调用记录。
不删除已发现接口。
不删除断点。
不删除 Session。
```

如果当前存在 paused 调用，需要确认：

```text
当前有 N 个请求暂停中，重置调试状态会全部放行，是否继续？
```

---

### 5.6 继续执行

作用：

```text
继续当前选中的 paused 调用。
```

行为：

```text
如果当前选中行为 paused：
  释放该调用。

如果当前没有选中 paused 行：
  自动选择最早暂停的一条并继续。

如果没有 paused 调用：
  按钮不可用。
```

UI 要求：

```text
按钮要明显。
建议使用播放图标。
文案示例：▶ 继续执行。
```

---

### 5.7 继续全部

作用：

```text
释放当前 Session 下所有 paused 调用。
```

UI 要求：

```text
按钮要明显。
建议使用快进图标。
文案示例：⏩ 继续全部。
```

---

### 5.8 主题切换

作用：

```text
切换亮色 / 暗色主题。
```

要求：

```text
放在顶部最右侧。
不参与调试状态机。
```

---

## 6. 按钮可用性矩阵

### 6.1 没有 Session

```text
新建 Session：可用
清空当前 Session：不可用
开始调试：可用，点击后自动新建 Session
停止调试：不可用
重置调试状态：不可用
继续执行：不可用
继续全部：不可用
主题切换：可用
```

### 6.2 有 Session，但未调试

```text
新建 Session：可用
清空当前 Session：可用
开始调试：可用
停止调试：不可用
重置调试状态：不可用
继续执行：不可用
继续全部：不可用
主题切换：可用
```

### 6.3 调试中，没有暂停调用

```text
新建 Session：可用，但需要确认，会停止当前调试
清空当前 Session：不可用
开始调试：不可用
停止调试：可用
重置调试状态：可用
继续执行：不可用
继续全部：不可用
主题切换：可用
```

### 6.4 调试中，有暂停调用

```text
新建 Session：可用，但需要确认，会放行暂停请求并结束当前调试
清空当前 Session：不可用
开始调试：不可用
停止调试：可用
重置调试状态：可用，但需要确认
继续执行：可用
继续全部：可用
主题切换：可用
```

---

## 7. 状态机设计

### 7.1 状态枚举

建议后端状态简化为：

```text
NO_SESSION
SESSION_IDLE
DEBUGGING
DEBUGGING_PAUSED
```

其中：

```text
NO_SESSION：
  当前没有选中的 Session。

SESSION_IDLE：
  有当前 Session，但未开始调试。

DEBUGGING：
  当前 Session 正在调试，pausedCount = 0。

DEBUGGING_PAUSED：
  当前 Session 正在调试，pausedCount > 0。
```

### 7.2 状态字段

后端 `/api/debug/state` 建议返回：

```json
{
  "success": true,
  "state": "DEBUGGING_PAUSED",
  "debugging": true,
  "currentSessionId": "debug-20260522-001",
  "callCount": 27,
  "interfaceCount": 12,
  "breakpointCount": 5,
  "pausedCount": 1,
  "runningCount": 0,
  "exceptionCount": 0,
  "lastReportTime": "2026-05-22T10:32:11",
  "theme": "dark"
}
```

---

## 8. Session 设计

### 8.1 Session 定位

Session 是一次独立的调试现场。

```text
一次新建 Session 后，所有调用记录和已发现接口都归属于该 Session。
```

Session 需要隔离：

```text
调用记录隔离。
已发现接口隔离。
接口统计隔离。
断点隔离。
```

断点隔离规则：

```text
断点默认只在当前 Session 内生效。
断点创建时必须写入 sessionId。
sourceSessionId / sourceInterfaceId / sourceCallId 只表示来源，不参与跨 Session 匹配。
第一版不支持跨 Session 断点。
```

### 8.2 Session 生命周期

```text
新建 Session：
  创建 Session，状态为 SESSION_IDLE。

开始调试：
  Session 状态进入 DEBUGGING。

停止调试：
  Session 状态退出 DEBUGGING，进入 SESSION_IDLE。
  Session 数据保留；同一个 Session 可再次开始调试，后续调用继续追加。

清空当前 Session：
  删除该 Session 下的调用记录和已发现接口，Session 本身可保留。

新建另一个 Session：
  当前 Session 变为历史 Session，新 Session 成为当前 Session。
```

建议 Session 表中保留 `status` 字段：

```text
created
idle
debugging
cleared
```

---

## 9. Java 调用页面处理

### 9.1 删除主 UI 中的 Java 调用页面

正式桌面端主 UI 删除：

```text
Java 调用 Tab。
Java 服务地址输入框。
测试连接按钮。
调用 initialize/control/error 等按钮。
桌面端主动请求 Java Demo 的 bridge 逻辑。
```

原因：

```text
MicroBreakpoint 应该是被 Java 上报驱动的断点调试器，不应该承担业务请求发起器职责。
```

### 9.2 保留开发脚本

建议新增或保留开发测试脚本：

```text
scripts/
  call_demo_initialize
  call_demo_control_create
  call_demo_control_start
  call_demo_control_stop
  call_demo_error
```

脚本用途：

```text
仅用于开发自测。
不进入桌面端主流程。
不作为产品核心功能。
```

---

## 10. DebugMethodInfo 重构设计

### 10.1 当前问题

当前 `DebugMethodInfo` 中已有：

```text
objectName
slotId
cmdName
serviceName
className
methodName
displayName
description
args
parameterMeta
```

但 `params` 目前只是被塞进 `args`：

```text
.arg("params", params)
.param("params", "操作传参", "java.util.Map")
```

这会导致 Python 后端需要从 `args.params` 中猜测业务参数，不利于：

```text
接口去重。
调用记录展示。
参数摘要生成。
参数快照断点。
未来参数条件断点。
```

### 10.2 新结构建议

`params` 必须成为顶层一等字段：

```text
DebugMethodInfo
  objectName       // SA / SG / 其他对象名
  cmdName          // create / start / stop / setFreq
  slotId           // Integer，可为 null
  description      // 中文描述
  params           // Map<String, Object>，顶层字段

  serviceName      // 可选，技术信息
  className        // 可选，技术信息
  methodName       // 可选，技术信息
  rawArgs          // 可选，完整原始入参
  parameterMeta    // 可选，参数元信息
```

### 10.3 字段规则

```text
objectName：
  用于页面分组。
  为空时归类到“未分类”，UI 给黄色警告。

cmdName：
  用于接口身份识别和断点匹配。
  为空时展示为“未知命令”，但应提示 Java 上报不完整。

slotId：
  可为 null。
  为空时数据库存 null。
  页面展示为“-”或“无槽位”。
  参与接口唯一键计算。

params：
  顶层字段。
  为空时统一为 {}。
  不参与接口唯一键。
  用于调用详情、参数样例、参数快照断点、未来参数条件断点。

rawArgs：
  可选。
  不参与主流程。
  只在详情页“技术信息”折叠区展示。

parameterMeta：
  可选。
  不参与主流程。
  用于展示顶层方法参数说明。
```

---

## 11. args 与 parameterMeta 是否保留

### 11.1 params

必须保留，且作为主流程字段。

用途：

```text
调用记录展示。
已发现接口最新参数样例。
参数摘要。
参数快照断点。
参数条件断点。
paramsFingerprint 计算。
```

### 11.2 args / rawArgs

建议保留，但降级为技术信息。

用途：

```text
兼容未来非标准 DebugMethodInfo 的方法调用。
排查 Java 侧上报问题。
保留完整原始入参快照。
```

要求：

```text
不参与接口唯一键。
不参与页面主列表展示。
只在详情页“技术信息”折叠区展示。
```

### 11.3 parameterMeta

建议保留，但降级为可选辅助信息。

用途：

```text
描述顶层方法参数。
辅助展示 params 这个参数的中文名和 Java 类型。
辅助未来生成接口文档。
```

要求：

```text
不强依赖它描述 params 内部字段。
不参与接口唯一键。
不参与断点匹配主逻辑。
```

---

## 12. 已发现接口唯一性规则

### 12.1 唯一键

已发现接口按 Session 隔离，唯一键为：

```text
sessionId + objectName + cmdName + slotId
```

即：

```text
interfaceUniqueKey = sessionId + objectName + cmdName + slotId
```

实现时需要注意 SQLite 的 `NULL` 唯一约束语义：

```text
slotId 可为 null，但 SQLite 的 UNIQUE 允许多个 NULL。
数据库中建议增加 slot_key 字段，将 null 统一归一化为 "__NULL__"。
唯一约束使用 unique(session_id, object_name, cmd_name, slot_key)。
页面和 API 仍暴露 slotId，slot_key 只作为数据库实现细节。
```

### 12.2 params 不参与唯一键

原因：

```text
同一个 objectName + cmdName + slotId，params 值不同，本质上仍然是同一个接口/命令的不同调用样例。
```

示例：

```text
SA + setPower + slotId=1
```

第一次：

```json
{"power": -10}
```

第二次：

```json
{"power": -20}
```

它们应该是同一个已发现接口，而不是两个接口。

### 12.3 params 的作用

params 应用于：

```text
保存最新样例。
保存历史样例数量。
保存历史样例 fingerprint 集合。
生成参数摘要。
生成 paramsFingerprint。
创建参数快照断点。
未来创建参数条件断点。
调用记录详情展示。
```

`paramsSampleCount` 不能只比较最新 fingerprint。若调用参数顺序为 A、B、A，只保存 latest fingerprint 会把第三次 A 误判为新样例。第一版建议增加 `interface_param_sample` 表，按 `interface_id + params_fingerprint` 去重；如果暂时不建表，至少保存 `params_fingerprints_json` 作为过渡。

---

## 13. paramsFingerprint 设计

虽然 params 不参与接口唯一键，但仍然需要生成 `paramsFingerprint`。

用途：

```text
参数快照断点。
调用记录参数一致性判断。
展示当前调用参数是否和断点参数一致。
```

### 13.1 规范化规则

计算 fingerprint 前，对 params 做规范化：

```text
Map key 排序。
嵌套 Map 递归排序。
List 保持原顺序。
null 保持 null。
空 params 统一为 {}。
字符串不自动 trim，避免误伤真实参数。
数字类型是否统一需要谨慎：
  第一版可以按 JSON 序列化后的结果计算；
  后续如需要，可单独处理 1 和 1.0 是否等价。
```

### 13.2 输出

```text
paramsFingerprint = sha256(normalizedParamsJson)
```

---

## 14. 调用记录数据模型

建议 `call_record` 字段：

```text
id
call_id
session_id
call_index

object_name
cmd_name
slot_id
description
params_json
params_fingerprint
params_summary

status
breakpoint_id
breakpoint_name
success
cost_ms
result_json
exception_type
exception_message

service_name
class_name
method_name
thread_name
raw_args_json
parameter_meta_json

created_at
continued_at
finished_at
updated_at
```

### 14.1 status 枚举

```text
created
running
paused
continued
finished
exception
timeout
ignored
```

### 14.2 主要状态含义

```text
running：
  Java 已上报 before-call，未命中断点，正在执行真实方法。

paused：
  命中断点，Java 正在等待继续。

continued：
  用户已点击继续，Java 已被释放，但 after-call 可能还未回来。

finished：
  Java after-call 成功返回。

exception：
  Java after-call 返回异常信息。

timeout：
  Java 等待超时自动继续。

ignored：
  非调试状态收到上报，不记录主流程时可不入库；如果入库则标记 ignored。
```

第一版建议非调试状态不上库，不需要 ignored。

---

## 15. 已发现接口数据模型

建议 `discovered_interface` 字段：

```text
id
session_id

object_name
cmd_name
slot_id
slot_key
description

latest_params_json
latest_params_fingerprint
params_schema_json
params_sample_count

call_count
success_count
exception_count
avg_cost_ms
max_cost_ms
min_cost_ms
first_seen_at
last_seen_at

created_at
updated_at
```

唯一约束：

```text
unique(session_id, object_name, cmd_name, slot_key)
```

其中 `slot_key` 是数据库内部字段：

```text
slotId 有值：slot_key = String(slotId)
slotId 为 null：slot_key = "__NULL__"
```

建议新增参数样例表：

```text
interface_param_sample

id
interface_id
params_fingerprint
params_json
first_seen_at
last_seen_at
seen_count

unique(interface_id, params_fingerprint)
```

### 15.1 发现或更新逻辑

收到 before-call 且 debugging=true：

```text
1. 从当前 Python 调试状态读取 currentSessionId。
2. 从 Java 上报中读取 objectName、cmdName、slotId、params。
3. 生成 slot_key 和 interfaceUniqueKey。
4. 如果接口不存在：
   - 创建 discovered_interface；
   - call_count = 1；
   - 保存 latest_params_json；
   - 保存 latest_params_fingerprint；
   - 写入 interface_param_sample；
   - params_sample_count = 1；
   - first_seen_at = 当前时间；
   - last_seen_at = 当前时间。
5. 如果接口已存在：
   - call_count + 1；
   - 更新 latest_params_json；
   - 更新 latest_params_fingerprint；
   - upsert interface_param_sample；
   - 只有 fingerprint 首次出现时，params_sample_count + 1；
   - 更新 last_seen_at。
```

收到 after-call：

```text
1. 根据 callId 找到 call_record。
2. 根据 call_record 找到 discovered_interface。
3. 更新 success_count / exception_count。
4. 更新 avg_cost_ms / max_cost_ms / min_cost_ms。
```

---

## 16. 断点数据模型

建议 `breakpoint` 字段：

```text
id
name
enabled

scope
session_id
object_name
cmd_name
slot_id
slot_key

match_mode
params_fingerprint
params_snapshot_json
conditions_json

hit_mode
hit_count
hit_limit

source_type
source_session_id
source_interface_id
source_call_id

created_at
updated_at
```

### 16.1 Session 归属与 scope

第一版固定为：

```text
session
```

含义：

```text
断点属于某一个 Session。
断点只匹配同一 Session 内的调用。
断点管理页只展示当前打开 Session 的断点。
打开历史 Session 时，断点管理页展示该历史 Session 的断点。
```

说明：

```text
Session 隔离调用记录、已发现接口、接口统计和断点。
source_session_id / source_interface_id / source_call_id 只记录断点创建来源。
断点匹配不得依赖 source_* 字段判断作用域。
第一版不支持 all_sessions。
```

### 16.2 match_mode

第一版建议支持：

```text
command_only
params_snapshot
params_condition
```

含义：

```text
command_only：
  匹配 objectName + cmdName + slotId。

params_snapshot：
  匹配 objectName + cmdName + slotId + paramsFingerprint。

params_condition：
  预留或第一版只支持简单等于判断。
```

### 16.3 hit_mode

保留旧设计中的命中模式：

```text
always
once
hit_count
```

含义：

```text
always：
  每次命中都暂停。

once：
  命中一次后自动禁用。

hit_count：
  命中到指定次数时暂停。
```

---

## 17. 断点匹配逻辑

收到 before-call 且 debugging=true：

```text
1. 取当前调用：
   sessionId
   objectName
   cmdName
   slotId
   slotKey
   paramsFingerprint
   params

2. 查询 enabled=true 且 session_id=currentSessionId 的断点。

3. 初步匹配：
   breakpoint.objectName == call.objectName
   breakpoint.cmdName == call.cmdName
   breakpoint.slotKey == call.slotKey

4. 根据 match_mode 判断：
   command_only：
     初步匹配成功即命中。

   params_snapshot：
     paramsFingerprint 也必须一致。

   params_condition：
     对 conditions_json 逐条判断。

5. 判断 hit_mode：
   always：
     直接暂停。

   once：
     暂停，并在命中后自动 disabled。

   hit_count：
     hit_count + 1；
     达到 hit_limit 时暂停。

6. 如果命中：
   更新断点 hit_count；
   创建 wait event；
   call_record.status = paused；
   返回 action=pause。
```

---

## 18. 参数条件断点预留设计

第一版可以不做完整 UI，但数据结构要预留。

建议 conditions_json 结构：

```json
[
  {
    "path": "params.frequency.start",
    "operator": "eq",
    "value": 1000000
  },
  {
    "path": "params.mode",
    "operator": "eq",
    "value": "AUTO"
  }
]
```

未来支持 operator：

```text
eq
ne
gt
gte
lt
lte
contains
exists
not_exists
```

第一版如要做最小能力，只支持：

```text
eq
exists
```

---

## 19. 后端 API 重构

### 19.1 删除

```text
POST /api/session/start-record
POST /api/session/stop-record
POST /api/session/start-debug
POST /api/session/stop-debug
POST /api/session/create
GET /api/session
```

本项目按新项目处理，不保留旧路径兼容层。前端、测试、README 必须同步切换到新 API。

---

### 19.2 Session API

#### 新建 Session

```text
POST /api/sessions
```

响应：

```json
{
  "success": true,
  "sessionId": "debug-20260522-001",
  "state": "SESSION_IDLE"
}
```

#### 清空当前 Session

```text
POST /api/sessions/current/clear
```

行为：

```text
调试中禁止清空。
删除当前 Session 下的 call_record、discovered_interface 和 interface_param_sample。
不删除当前 Session 的 breakpoint。
breakpoint 必须自包含完整匹配字段，不能依赖已删除的来源调用或接口。
```

#### 获取 Session 列表

```text
GET /api/sessions
```

#### 切换当前 Session

```text
POST /api/sessions/{sessionId}/select
```

#### 删除 Session

```text
DELETE /api/sessions/{sessionId}
```

行为：

```text
调试中禁止删除。
删除目标 Session 下的调用记录、已发现接口、参数样例和断点。
如果删除的是当前 Session，删除后进入 NO_SESSION。
```

---

### 19.3 调试 API

#### 开始调试

```text
POST /api/debug/start
```

行为：

```text
如果没有当前 Session，自动创建。
设置 debugging=true。
当前 Session 状态改为 debugging。
如果当前 Session 已经调试过，继续向同一 Session 追加新的调用记录和已发现接口更新。
```

#### 停止调试

```text
POST /api/debug/stop
```

行为：

```text
设置 debugging=false。
释放所有 paused 调用。
当前 Session 状态改为 idle。
保留当前 Session 数据，允许后续再次开始调试并继续追加。
```

#### 重置调试状态

```text
POST /api/debug/reset
```

行为：

```text
释放所有 paused 调用。
清空临时命中提示。
清空临时选中态。
不删除调用记录。
不删除已发现接口。
不删除断点。
```

#### 获取当前状态

```text
GET /api/debug/state
```

---

### 19.4 Java 上报 API

#### before-call

```text
POST /api/calls/before
```

请求建议：

```json
{
  "callId": "uuid",
  "objectName": "SA",
  "cmdName": "start",
  "slotId": 1,
  "description": "启动扫描",
  "params": {
    "mode": "AUTO"
  },

  "serviceName": "instrument-service-demo",
  "className": "xxx",
  "methodName": "xxx",
  "threadName": "http-nio-8080-exec-1",
  "rawArgs": {},
  "parameterMeta": [],
  "timestamp": "2026-05-22T10:32:11"
}
```

请求体不包含 `sessionId`。后端使用当前调试状态中的 `currentSessionId` 归属调用记录、接口发现和断点匹配。

响应：

```json
{
  "success": true,
  "callIndex": 12,
  "action": "pause",
  "reason": "breakpoint matched",
  "waitTimeoutMs": 300000,
  "breakpointId": 5,
  "breakpointName": "SA start slot=1"
}
```

action：

```text
continue
pause
```

#### after-call

```text
POST /api/calls/after
```

请求：

```json
{
  "callId": "uuid",
  "success": true,
  "costMs": 12,
  "result": {},
  "exceptionType": null,
  "exceptionMessage": null
}
```

处理规则：

```text
无论当前 debugging 是否为 true，after-call 都按 callId 尝试更新已有调用记录。
如果 callId 不存在，说明对应 before-call 没有在调试状态下入库，直接返回 success 并忽略。
```

---

### 19.5 调用记录 API

#### 分组查询调用记录

```text
GET /api/calls/grouped?sessionId=xxx
```

返回结构建议：

```json
{
  "success": true,
  "sessionId": "debug-20260522-001",
  "groups": [
    {
      "objectName": "SA",
      "callCount": 21,
      "pausedCount": 1,
      "exceptionCount": 0,
      "items": []
    }
  ]
}
```

每个分组内部支持参数：

```text
keyword
status
sortBy
sortOrder
page
pageSize
```

建议接口形式：

```text
GET /api/calls/grouped
GET /api/calls?sessionId=xxx&objectName=SA&keyword=xxx&status=paused&sortBy=createdAt
```

#### 查询调用详情

```text
GET /api/calls/{callId}
```

#### 继续指定调用

```text
POST /api/calls/{callId}/continue
```

#### 继续全部

```text
POST /api/calls/continue-all
```

---

### 19.6 已发现接口 API

#### 分组查询接口

```text
GET /api/interfaces/grouped?sessionId=xxx
```

返回结构建议：

```json
{
  "success": true,
  "sessionId": "debug-20260522-001",
  "groups": [
    {
      "objectName": "SA",
      "interfaceCount": 12,
      "callCount": 86,
      "exceptionCount": 2,
      "lastSeenAt": "2026-05-22T10:31:22",
      "items": []
    }
  ]
}
```

每个分组内部支持：

```text
keyword
status
sortBy
sortOrder
page
pageSize
```

#### 查询接口详情

```text
GET /api/interfaces/{interfaceId}
```

#### 从接口创建断点

```text
POST /api/interfaces/{interfaceId}/breakpoint
```

---

### 19.7 断点 API

```text
GET    /api/breakpoints
POST   /api/breakpoints
PUT    /api/breakpoints/{breakpointId}
DELETE /api/breakpoints/{breakpointId}
POST   /api/breakpoints/{breakpointId}/enable
POST   /api/breakpoints/{breakpointId}/disable
```

#### 从调用记录创建断点

```text
POST /api/calls/{callId}/breakpoint
```

请求：

```json
{
  "name": "SA start slot=1",
  "matchMode": "command_only",
  "hitMode": "always"
}
```

参数快照断点：

```json
{
  "name": "SA start slot=1 params snapshot",
  "matchMode": "params_snapshot",
  "hitMode": "always"
}
```

---

## 20. 桌面端页面结构

### 20.1 顶部工具栏

布局：

```text
[新建 Session] [清空当前 Session] | [开始调试] [停止调试] [重置调试状态] | [继续执行] [继续全部] | [主题切换]
```

要求：

```text
按钮要大。
图标要明显。
核心按钮颜色要有区分。
继续执行、继续全部在 pausedCount > 0 时高亮。
```

---

### 20.2 状态栏

状态栏必须明显展示：

```text
后端状态
当前 Session
调试状态
调用总数
已发现接口数
断点数量
暂停数量
异常数量
最近上报时间
```

示例：

```text
🟢 后端运行中 | Session: debug-20260522-001 | 🔵 调试中 | 调用 27 | 接口 12 | 断点 5 | ⏸ 暂停 1 | ❌ 异常 0 | 最近上报 10:32:11
```

如果处于暂停状态，顶部增加醒目提示条：

```text
⏸ 命中断点：SA / start / slot=1，Java 请求已暂停，请点击“继续执行”或“继续全部”。
```

---

## 21. Tab 页面设计

最终主 Tab：

```text
调用记录
已发现接口
断点管理
历史 Session
设置
```

删除：

```text
Java 调用
```

---

## 22. 调用记录页面设计

调用记录按 objectName 分组展示。

### 22.1 页面顶部

```text
调用记录
当前 Session：debug-20260522-001
状态：调试中
调用总数：27
暂停中：1
异常：0
```

### 22.2 分组卡片

```text
▼ SA    调用 21 次    暂停 1 次    异常 0 次
  [搜索 SA 调用...] [状态过滤] [排序]

  #   命令      槽位    中文描述    状态        耗时    调用时间      断点
  1   create    1       创建仪表    finished    12ms    10:21:03     -
  2   start     1       启动扫描    paused      -       10:21:05     命中
  3   stop      1       停止扫描    finished    7ms     10:21:08     -

▼ SG    调用 8 次     暂停 0 次    异常 1 次
```

### 22.3 分组内部搜索过滤排序

每个 objectName 分组内独立支持：

```text
搜索：
  cmdName
  description
  paramsSummary
  exceptionMessage

过滤：
  全部
  running
  paused
  finished
  exception
  timeout
  命中断点
  未命中断点

排序：
  调用序号
  调用时间
  状态
  耗时
  cmdName
```

不做全局 objectName 搜索和排序。

### 22.4 状态视觉反馈

```text
paused：
  整行高亮。
  左侧显示暂停图标。
  自动滚动到该行。
  自动打开详情。
  顶部继续执行按钮高亮。

exception：
  红色错误图标。
  行内显示异常摘要。

finished：
  绿色完成图标。

running：
  加载动画或旋转图标。

continued：
  蓝色播放图标。

timeout：
  橙色超时图标。
```

### 22.5 调用详情面板

点击调用记录后，右侧详情显示：

```text
业务信息：
  objectName
  cmdName
  slotId
  description
  params JSON

调试信息：
  callIndex
  callId
  status
  breakpointId
  breakpointName
  pauseDuration
  costMs
  createdAt
  continuedAt
  finishedAt

结果信息：
  success
  result JSON
  exceptionType
  exceptionMessage

技术信息，默认折叠：
  serviceName
  className
  methodName
  threadName
  rawArgs JSON
  parameterMeta JSON
```

---

## 23. 已发现接口页面设计

已发现接口按 objectName 分组展示。

### 23.1 页面顶部

```text
已发现接口
当前 Session：debug-20260522-001
发现对象：SA、SG、未分类
接口总数：32
```

### 23.2 分组卡片

```text
▼ SA    12 个接口    调用 86 次    异常 2 次    最近 10:31:22
  [搜索 SA 内接口...] [状态过滤] [排序]

  命令        槽位    中文描述      调用次数    状态      平均耗时    最后调用
  create      1       创建仪表      20         正常      12ms        10:30:01
  start       1       启动扫描      15         有断点    8ms         10:30:13
  stop        1       停止扫描      13         正常      7ms         10:30:20

▶ SG    8 个接口     调用 34 次    异常 0 次    最近 10:29:11

▼ 未分类    2 个接口    调用 3 次    异常 1 次
  ⚠ objectName 为空，请检查 Java 上报数据
```

### 23.3 分组内部搜索过滤排序

每个 objectName 分组内部支持：

```text
搜索：
  cmdName
  description
  paramsSummary

过滤：
  全部
  有断点
  无断点
  有异常
  最近调用

排序：
  最近调用
  调用次数
  异常次数
  平均耗时
  cmdName
```

不做 objectName 全局搜索和排序。

### 23.4 接口详情面板

点击接口后，右侧显示：

```text
基础信息：
  objectName
  cmdName
  slotId
  description
  interfaceUniqueKey

参数信息：
  latestParams JSON
  paramsFingerprint
  paramsSampleCount
  params 字段树

统计信息：
  callCount
  successCount
  exceptionCount
  avgCostMs
  maxCostMs
  minCostMs
  firstSeenAt
  lastSeenAt

关联操作：
  创建命令断点
  按最新参数创建快照断点
  查看相关调用
  复制 params
  复制接口信息
```

---

## 24. 断点管理页面设计

### 24.1 列表字段

```text
启用状态
断点名称
对象 objectName
命令 cmdName
槽位 slotId
匹配模式
参数条件摘要
命中模式
命中次数
来源
创建时间
```

### 24.2 操作

```text
新增断点
编辑断点
启用
禁用
删除
复制断点
查看命中记录
```

### 24.3 匹配模式展示

```text
command_only：
  命令断点

params_snapshot：
  参数快照断点

params_condition：
  参数条件断点
```

### 24.4 断点创建入口

入口来源：

```text
1. 断点管理页面手工创建。
2. 已发现接口页面：创建命令断点。
3. 已发现接口页面：按最新参数创建快照断点。
4. 调用记录页面：按当前调用创建命令断点。
5. 调用记录页面：按当前调用 params 创建快照断点。
```

---

## 25. 历史 Session 页面设计

### 25.1 列表字段

```text
Session ID
状态
开始时间
结束时间
调用次数
接口数量
异常数
暂停次数
备注
```

### 25.2 操作

```text
打开 Session
删除 Session
导出 Session
复制 Session ID
```

### 25.3 打开历史 Session

打开历史 Session 后：

```text
调用记录页面展示该 Session 的调用。
已发现接口页面展示该 Session 的接口。
断点管理展示该 Session 的断点。
```

如果历史 Session 不处于 debugging，页面应明确提示：

```text
当前正在查看历史 Session，未处于调试状态。
```

---

## 26. 设置页面设计

建议设置项：

```text
Python 后端端口
Java 上报 token
默认 wait 超时时间
最大保留 Session 数量
每个 Session 最大调用记录数
是否保存 rawArgs
是否保存 resultJson
主题模式
```

---

## 27. UI 易用性要求

本项目是断点调试工具，不是普通后台管理系统。UI 必须强调状态反馈。

### 27.1 按钮

```text
核心按钮要大。
继续执行和继续全部不能藏在小图标里。
按钮图标要明显。
危险操作使用红色或警告色。
```

### 27.2 暂停反馈

命中断点时必须做到：

```text
顶部出现明显提示条。
调用记录自动滚动到 paused 行。
paused 行高亮。
右侧详情自动打开。
继续执行按钮高亮。
状态栏 pausedCount 更新。
```

### 27.3 空状态

调用记录为空：

```text
当前 Session 暂无调用。
点击“开始调试”后，手动调用 Java Demo 或真实业务接口，调用记录会显示在这里。
```

已发现接口为空：

```text
还没有发现接口。
点击“开始调试”后，手动调用 Java Demo 或真实业务接口，接口会自动出现在这里。
```

没有 Session：

```text
还没有 Session。
请点击“新建 Session”或直接点击“开始调试”。
```

### 27.4 objectName 异常

如果 objectName 为空：

```text
归类到“未分类”。
分组头显示黄色警告。
详情中提示：objectName 为空，请检查 Java 上报数据。
```

### 27.5 slotId 为空

```text
数据库存 null。
页面展示为 “-” 或 “无槽位”。
参与唯一键计算。
```

---

## 28. 后端服务模块调整

建议模块：

```text
StateService
SessionService
CallRecordService
InterfaceDiscoverService
BreakpointService
WaitManager
ParamsFingerprintService
```

### 28.1 StateService

职责：

```text
维护当前 Session。
维护 debugging 状态。
维护 pausedCount。
提供 /api/debug/state 所需数据。
```

### 28.2 SessionService

职责：

```text
新建 Session。
选择 Session。
清空当前 Session。
开始调试。
停止调试。
查询历史 Session。
```

### 28.3 CallRecordService

职责：

```text
创建调用记录。
更新调用结果。
更新调用状态。
按 objectName 分组查询调用记录。
查询调用详情。
```

### 28.4 InterfaceDiscoverService

职责：

```text
根据 before-call 发现或更新接口。
使用 sessionId + objectName + cmdName + slotId 唯一键。
维护接口统计。
维护 latestParams 和 paramsSampleCount。
```

### 28.5 BreakpointService

职责：

```text
创建断点。
编辑断点。
启用 / 禁用断点。
判断调用是否命中断点。
维护命中次数。
处理 once / hit_count 模式。
```

### 28.6 WaitManager

职责：

```text
创建 wait event。
等待 callId。
继续指定 callId。
继续全部。
停止调试时释放全部。
重置调试状态时释放全部。
超时自动释放。
线程安全。
```

### 28.7 ParamsFingerprintService

职责：

```text
规范化 params。
生成 normalizedParamsJson。
生成 sha256 fingerprint。
生成 paramsSummary。
```

---

## 29. Java 侧调整

### 29.1 DebugMethodInfo

需要增加顶层字段：

```text
params
```

建议 Builder 方法：

```text
params(Map<String, Object> params)
```

### 29.2 before-call 上报

Java 上报必须包含：

```text
objectName
cmdName
slotId
description
params
```

可选包含：

```text
serviceName
className
methodName
threadName
rawArgs
parameterMeta
```

Java 不上传 sessionId。调用归属由 Python 后端当前选中的 Session 决定，避免业务服务感知调试器的 Session 状态。

### 29.3 Java 不再依赖记录模式

Java 侧无需知道“记录模式”。

Java 只需要：

```text
调用前上报 before-call。
根据 Python 返回 action 判断 continue / pause。
调用后上报 after-call。
```

Python 在非 debugging 状态会直接返回 continue。

### 29.4 容错要求

Java DebugClient 必须满足：

```text
Python 服务不可用时，before-call 失败直接放行。
after-call 失败只打印日志。
wait 请求失败直接放行。
wait 必须有超时。
停止调试时 Python 释放所有等待。
不允许 Java 业务线程永久卡死。
```

---

## 30. 清理项

### 30.1 前端清理

删除：

```text
开始记录按钮。
停止记录按钮。
Java 调用 Tab。
Java 服务地址输入框。
测试连接按钮。
主动调用 Java Demo 的 UI 逻辑。
```

保留：

```text
开始调试。
停止调试。
继续执行。
继续全部。
刷新/状态刷新能力。
```

新增：

```text
新建 Session。
清空当前 Session。
重置调试状态。
主题切换。
```

### 30.2 后端清理

删除：

```text
start-record API。
stop-record API。
旧的 start-debug API。
旧的 stop-debug API。
旧的 /api/session 单数路径。
recording 模式。
record session 类型。
```

新增并使用：

```text
POST /api/debug/start。
POST /api/debug/stop。
POST /api/debug/reset。
before-call。
after-call。
continue。
continue-all。
state。
```

### 30.3 数据库清理

如果已有旧数据库，可选择：

```text
开发阶段直接重建数据库。
或增加 migration 脚本。
```

推荐开发阶段：

```text
优先重建数据库，减少迁移复杂度。
```

---

## 31. 推荐实施顺序

### 第 1 阶段：状态机、API 和按钮重构

```text
1. 删除开始记录 / 停止记录。
2. 切换到新 API：/api/sessions、/api/debug/start、/api/debug/stop、/api/debug/reset。
3. 新增新建 Session / 清空当前 Session / 重置调试状态。
4. 开始调试时创建或使用当前 Session。
5. 非 debugging 状态 before-call 直接 continue，不入库。
6. 停止调试释放所有 paused 调用。
7. 停止调试后同一 Session 可再次开始，并继续追加数据。
```

验收：

```text
未开始调试时，调用 Java 接口不会产生调用记录和已发现接口。
开始调试后，调用 Java 接口会产生记录和接口。
停止调试后，再调用 Java 接口不会新增数据。
同一 Session 再次开始调试后，调用记录继续追加到该 Session。
```

---

### 第 2 阶段：DebugMethodInfo 和 Java 上报重构

```text
1. params 提升为 DebugMethodInfo 顶层字段。
2. before-call 上报 objectName/cmdName/slotId/description/params。
3. rawArgs/parameterMeta 改为可选技术字段。
4. slotId 为空时传 null。
5. objectName 为空时允许上报，但后端归入“未分类”。
```

验收：

```text
Python 后端能直接读取 params 字段。
调用记录中能展示 objectName/cmdName/slotId/params。
```

---

### 第 3 阶段：数据模型和接口发现重构

```text
1. call_record 增加 objectName/cmdName/slotId/params 字段。
2. discovered_interface 唯一键改为 sessionId + objectName + cmdName + slot_key。
3. 实现 paramsFingerprint。
4. 实现 paramsSummary。
5. 实现 interface_param_sample 或等价的 fingerprint 去重存储。
6. 接口发现按 Session 隔离。
```

验收：

```text
同一 Session 内，相同 objectName/cmdName/slotId 只生成一个已发现接口。
params 不同只更新参数样例，不新增接口。
不同 Session 中相同接口各自隔离。
```

---

### 第 4 阶段：断点模型重构

```text
1. 断点从 methodName 维度改为 sessionId + objectName/cmdName/slot_key 维度。
2. 支持 command_only 断点。
3. 支持 params_snapshot 断点。
4. 预留 params_condition。
5. 断点默认只在当前 Session 内生效。
6. source_* 字段只表示创建来源，不参与匹配作用域判断。
```

验收：

```text
从已发现接口创建命令断点。
从调用记录创建命令断点。
从调用记录创建参数快照断点。
命中断点后 Java 请求暂停。
继续执行后 Java 请求恢复。
不同 Session 中相同 objectName/cmdName/slotId 不互相命中断点。
```

---

### 第 5 阶段：分组 API

```text
1. 实现 /api/calls/grouped。
2. 实现 /api/interfaces/grouped。
3. 每个 objectName 分组返回统计信息。
4. 分组内部支持搜索、过滤、排序。
```

验收：

```text
调用记录按 objectName 分组。
已发现接口按 objectName 分组。
objectName 为空时归入“未分类”。
```

---

### 第 6 阶段：桌面端页面重构

```text
1. 顶部按钮按新区分布局。
2. 删除 Java 调用 Tab。
3. 调用记录页面改为 objectName 折叠分组。
4. 已发现接口页面改为 objectName 折叠分组。
5. 每个分组内部增加搜索、过滤、排序。
6. 右侧详情面板展示业务信息、调试信息、结果信息、技术信息。
```

验收：

```text
页面能清楚展示当前 Session。
paused 行明显高亮。
点击 paused 行后，继续执行可用。
继续全部能释放所有 paused。
```

---

### 第 7 阶段：UI 反馈增强

```text
1. 命中断点时顶部提示条。
2. 自动滚动到 paused 行。
3. 自动打开详情。
4. 继续执行按钮高亮。
5. 空状态提示优化。
6. objectName 为空警告。
7. 图标和按钮尺寸优化。
```

验收：

```text
用户一眼能看出是否调试中。
用户一眼能看出是否有请求暂停。
用户一眼能找到继续执行按钮。
```

### 每阶段验证要求

每个阶段完成后至少执行：

```powershell
conda activate micro-breakpoint
cd python-debugger
pytest

cd ..\java-demo
mvn test
```

涉及 QML、窗口状态、按钮可用性或主题变更时，还需要完成一次桌面端启动 smoke：

```powershell
conda activate micro-breakpoint
cd python-debugger
python run_desktop.py
```

如果阶段改动了用户工作流、API 路径、启动方式或数据模型，必须同步更新项目根目录 `README.md`。

---

## 32. 验收场景

### 32.1 未开始调试

```text
1. 启动 Python 后端。
2. 启动桌面端。
3. 启动 Java Demo。
4. 不点击开始调试。
5. 手动调用 Java Demo 接口。
6. 调用记录不新增。
7. 已发现接口不新增。
8. Java 请求正常返回。
```

### 32.2 开始调试后发现接口

```text
1. 点击新建 Session。
2. 点击开始调试。
3. 手动调用 Java Demo control 接口。
4. 调用记录新增一条。
5. 已发现接口中出现对应 objectName 分组。
6. 分组下出现对应 cmdName + slotId 接口。
```

### 32.3 相同接口不同 params

```text
1. 同一 Session 内调用 SA/start/slot=1，params={"mode":"A"}。
2. 再调用 SA/start/slot=1，params={"mode":"B"}。
3. 已发现接口仍只有一条 SA/start/slot=1。
4. 接口 callCount = 2。
5. latestParams 更新为最新一次。
6. paramsSampleCount 正确增加。
```

### 32.4 不同 Session 隔离

```text
1. Session A 调用 SA/start/slot=1。
2. 新建 Session B。
3. Session B 调用 SA/start/slot=1。
4. Session A 和 Session B 各自有独立的已发现接口记录。
5. Session A 的断点不会命中 Session B 的调用。
```

### 32.5 同一 Session 停止后继续追加

```text
1. Session A 点击开始调试。
2. 调用 SA/start/slot=1，生成调用记录 #1。
3. 点击停止调试。
4. 再次点击开始调试。
5. 调用 SA/stop/slot=1，生成调用记录 #2。
6. 两条调用记录都属于 Session A，接口发现和统计继续累加。
```

### 32.6 命令断点

```text
1. 从已发现接口 SA/start/slot=1 创建 command_only 断点。
2. 点击开始调试。
3. 调用 SA/start/slot=1。
4. Java 请求暂停。
5. UI paused 行高亮。
6. 点击继续执行。
7. Java 请求恢复并返回。
```

### 32.7 参数快照断点

```text
1. 从某条调用记录创建 params_snapshot 断点。
2. 使用相同 params 再次调用。
3. 请求暂停。
4. 使用不同 params 调用。
5. 请求不暂停。
```

### 32.8 停止调试释放暂停

```text
1. 命中断点后 Java 请求 paused。
2. 点击停止调试。
3. UI 提示会释放暂停请求。
4. 确认后，Java 请求恢复。
5. debugging=false。
```

### 32.9 重置调试状态

```text
1. 调试中命中多个断点。
2. 点击重置调试状态。
3. UI 提示会释放所有暂停请求。
4. 确认后，全部 paused 请求恢复。
5. 调用记录不删除。
6. 已发现接口不删除。
```

---

## 33. Codex 执行要求

Codex 重构时必须遵守：

```text
1. 不要一次性大爆炸改动。
2. 按阶段逐步提交。
3. 每完成一个阶段必须运行测试或至少完成手动验证。
4. 每个阶段完成后提交 commit。
5. 不要删除“开始调试”中的接口发现能力。
6. 删除记录按钮时，不得删除 before-call 中的接口发现逻辑。
7. 删除 Java 调用 UI 时，可以保留开发测试脚本。
8. params 必须成为顶层字段。
9. args / parameterMeta 可以保留，但不得作为主流程依赖。
10. 已发现接口必须按 Session 隔离。
11. 断点必须按 Session 隔离，不得默认跨 Session 生效。
12. 已发现接口唯一键必须是 sessionId + objectName + cmdName + slot_key。
13. params 不得参与接口唯一键。
14. source_* 字段只记录来源，不参与断点作用域判断。
15. 停止调试后同一 Session 必须允许再次开始并继续追加数据。
16. UI 必须保证 paused 状态强反馈。
17. 改动用户工作流、API、启动方式或数据模型时必须同步更新 README.md。
```

---

## 34. 推荐 commit 拆分

```text
feat: 重构调试状态机并移除记录模式

feat: 新增 Session 管理与调试控制按钮

refactor: 调整 DebugMethodInfo 上报结构并提升 params 为顶层字段

refactor: 按 Session 隔离接口和断点并调整唯一键

feat: 新增调用记录和已发现接口 objectName 分组查询

refactor: 重构调用记录与已发现接口页面布局

feat: 基于 sessionId/objectName/cmdName/slotKey 重构断点匹配模型

feat: 增强断点命中与暂停状态 UI 反馈

chore: 移除 Java 调用页面并补充开发测试脚本
```

---

## 35. 最终目标效果

重构完成后，MicroBreakpoint 的核心体验应该是：

```text
用户打开工具。
点击新建 Session。
点击开始调试。
手动调用 Java Demo 或真实微服务接口。
页面按 SA、SG 等 objectName 自动分组展示调用记录和已发现接口。
命中断点时，页面强提示并高亮 paused 调用。
用户点击继续执行或继续全部，Java 请求恢复。
停止调试后，本次 Session 数据保留，可作为历史调试现场查看。
再次开始同一个 Session 时，新调用继续追加到该 Session，断点仍只在该 Session 内生效。
```

一句话总结：

```text
MicroBreakpoint 从“记录按钮驱动的接口采集工具”，重构为“Session 驱动的 Java 微服务接口断点调试器”。
```
