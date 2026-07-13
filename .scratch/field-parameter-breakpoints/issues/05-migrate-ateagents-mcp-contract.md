# 05 — 迁移 AteAgents 的 `declare_breakpoint` MCP 契约

**What to build:** 让 AI Agent 继续通过现有 `declare_breakpoint` MCP 工具声明接口级或字段参数断点，并以严格、可核验且禁止猜测的契约生成字段条件、完成 HITL 审批、调用 MicroBreakpoint 和理解规范化结果。

**Blocked by:** 04 — 补全创建反馈与命中解释。

**Status:** ready-for-agent

## Acceptance criteria

- [ ] 继续使用一个 `declare_breakpoint` 工具；`match_type=interface` 表示接口级断点，`match_type=parameters` 投影为字段参数断点。
- [ ] 接口级声明允许省略或传入空条件；参数级声明必须提供非空条件列表，且不会因“至少一个条件”的要求破坏接口级断点。
- [ ] MCP 条件只包含 `field_path`、`operator`、`value`，并严格限制为 `eq` 和 `contains_any` 及其对应值类型。
- [ ] MCP 在调用后端前返回可纠正的结构化错误；后端仍独立执行同一契约校验。
- [ ] 工具把规范化目标和条件准确投影到 MicroBreakpoint，并把规范化规则、创建/复用/重新启用状态、模式切换副作用及目标观测完整返回给 Agent。
- [ ] 保留现有目标路由和 HITL 边界；审批卡展示目标及规范化条件，不额外要求重复的自然语言确认。
- [ ] Agent 指令和知识引用明确禁止猜测字段路径及 JSON 值类型，只允许采用用户陈述、知识库或真实调用观测提供的证据。
- [ ] Agent 指引不再生成旧字段别名、旧操作符或旧参数匹配模式，并能利用接口摘要和逐条件观测核验声明结果。
- [ ] MCP 契约测试覆盖工具 schema、条件式校验、HTTP 投影、HITL 注册、结构化错误和规范化响应传播。
- [ ] 实现和验证时不修改或提交 AteAgents 工作区内与本需求无关的既有变更。
