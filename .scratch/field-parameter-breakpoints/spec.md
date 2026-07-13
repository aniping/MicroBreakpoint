# 字段参数断点重构规格

Status: ready-for-agent

## Problem Statement

用户需要在某个业务对象和命令被调用时，根据请求参数中的具体字段决定是否暂停。现有参数断点同时存在整份参数快照、字段条件、路径别名、多种运算符和字符串化比较，桌面端、Agent API、Java 后端与 Flask 后端对同一规则的理解也不完全一致。AI Agent 虽然已经能够调用断点声明工具，但当前条件字段和操作符契约存在漂移，无法可靠地从用户话术生成可执行的字段参数断点。

用户首先需要两个明确场景：使用 `eq` 对数字、字符串和 bool 做完全匹配；使用 `contains_any` 判断实际请求列表是否包含用户指定候选值中的任意一个。规则必须支持对象深层字段路径、多个字段条件的 AND 组合，并且不能影响现有接口级命令断点。创建结果还需要提供足够的接口和最近调用信息，帮助 Agent 判断断点是否设置正确。

## Solution

将旧参数断点完整替换为单一的“字段参数断点”模型。字段参数断点绑定一个 Session、业务对象和命令，基于完整原始请求参数执行匹配。每条规则包含非空字段条件集，字段路径唯一、顺序无关，所有条件按 AND 组合。第一版只支持 `eq` 和 `contains_any`，并使用统一的基本类型与完全匹配语义。

MicroBreakpoint 负责规范化、校验、持久化、运行时匹配和命中解释，并在 Java 与 Flask 后端保持完全相同的行为。AteAgents 继续复用现有 `declare_breakpoint` MCP 工具，通过 `match_type=parameters` 声明字段参数断点，沿用目标路由和 HITL 审批。桌面端只展示和管理字段参数断点，不提供创建或编辑入口。

旧 `params_snapshot`、旧 `params_condition`、旧路径别名、旧操作符和旧存储字段全部移除。软件尚未发布，不提供旧数据库、旧规则或旧归档迁移。

## User Stories

1. As a debugger user, I want to pause one specific business command only when a request field equals my expected value, so that unrelated calls continue normally.
2. As a debugger user, I want integer and decimal representations of the same numeric value to match, so that `4` and `4.0` do not create accidental misses.
3. As a debugger user, I want strings to match with case and whitespace preserved, so that the breakpoint reflects the exact business value.
4. As a debugger user, I want bool values to match only bool values, so that `true`, `1`, and `"true"` are never confused.
5. As a debugger user, I want to target a nested request field such as `a.b.c`, so that deeply structured business parameters can control pausing.
6. As a debugger user, I want all fields in one rule to use AND semantics, so that the call pauses only when the complete intended condition is satisfied.
7. As a debugger user, I want separate field parameter rules to use OR semantics, so that any explicitly declared scenario can pause the call.
8. As a debugger user, I want a `contains_any` condition for list-valued fields, so that a request such as `testChannel=[1,2,3,4]` can match user candidates `4` or `5`.
9. As a debugger user, I want `contains_any` candidate order and duplicates to be irrelevant, so that equivalent user requests produce the same rule.
10. As a debugger user, I want non-basic values inside an actual request list to be ignored, so that mixed business lists do not cause matcher failures.
11. As a debugger user, I want missing fields and incompatible runtime types to produce a safe non-match, so that debugger rules never break the business call.
12. As a debugger user, I want malformed rule declarations rejected before activation, so that invalid rules cannot silently pause the wrong calls.
13. As a debugger user, I want field parameter breakpoints to remain active after each hit, so that every subsequent matching call pauses until I disable or delete the rule.
14. As a debugger user, I want an interface-level command breakpoint and field parameter breakpoints on the same target to be mutually exclusive, so that an unconditional rule cannot shadow conditional rules.
15. As a debugger user, I want multiple field parameter rules on the same target to coexist, so that I can represent alternative scenarios without expression trees.
16. As a debugger user, I want the first created matching rule to be the single pause reason, so that one call has one deterministic breakpoint identity.
17. As a debugger user, I want field parameter breakpoints scoped to one Session, so that rules do not leak into unrelated debugging work.
18. As a debugger user, I want clearing call records to preserve field parameter breakpoints, so that I can rerun a scenario with the same rules.
19. As a debugger user, I want clearing or deleting a Session to remove its field parameter breakpoints, so that Session lifecycle remains coherent.
20. As a debugger user, I want field parameter rules to apply across all slots for the target command, so that synthetic slot metadata does not change business-field matching.
21. As an AI Agent, I want to use the existing `declare_breakpoint` tool for both interface and field parameter breakpoints, so that there is one creation workflow and one HITL policy.
22. As an AI Agent, I want `match_type=interface` to allow no conditions and `match_type=parameters` to require conditions, so that interface-level functionality remains unaffected.
23. As an AI Agent, I want each condition to use only `field_path`, `operator`, and `value`, so that I can generate one canonical contract without aliases.
24. As an AI Agent, I want every condition operator to be explicit, so that omitted operators cannot silently change rule meaning.
25. As an AI Agent, I want unknown fields, misspellings, old aliases, and unsupported operators rejected with structured details, so that I can correct the tool call.
26. As an AI Agent, I want to declare a rule before the target interface has been observed, so that I can arm breakpoints before starting a test flow.
27. As an AI Agent, I want to receive the normalized stored rule after declaration, so that I can verify the backend accepted exactly what I intended.
28. As an AI Agent, I want declaration results to say whether a rule was created, reused, or re-enabled, so that I can report the actual state change accurately.
29. As an AI Agent, I want declaration results to list interface breakpoints disabled by mode conflict, so that I can explain secondary effects to the user.
30. As an AI Agent, I want an observed-interface summary and the latest call's per-condition observations, so that I can judge whether the chosen fields and values look correct.
31. As an AI Agent, I want unobserved-target information to remain advisory, so that lack of history does not block a valid rule.
32. As an AI Agent, I want to explain why a recorded interaction matched or did not match each condition, so that users can debug their breakpoint rules.
33. As an AI Agent, I want field paths to come from the user, the knowledge base, or real call evidence, so that I never invent parameter names.
34. As an AI Agent, I want condition value types to come from the user, the knowledge base, or real call evidence, so that strict matching is not undermined by guessed JSON types.
35. As an AI Agent, I want breakpoint creation to use the existing HITL confirmation card, so that state changes remain explicitly approved.
36. As an AI Agent, I want the HITL card to show the target and normalized conditions without a second prose confirmation, so that approval is clear and non-redundant.
37. As an API caller, I want both the Agent API and generic breakpoint API to apply the same field-rule validator, so that behavior cannot be bypassed through a different endpoint.
38. As an API caller, I want duplicate declarations to reuse the same rule identifier, so that declaration is idempotent.
39. As an API caller, I want redeclaring a disabled identical rule to re-enable it after approval, so that I can restore a rule without creating a duplicate.
40. As a desktop user, I want field parameter breakpoints labeled consistently, so that old “condition breakpoint” and “parameter snapshot” terms no longer cause confusion.
41. As a desktop user, I want conditions displayed as structured rows under an “all conditions” group, so that AND rules remain readable.
42. As a desktop user, I want list candidates and bool values displayed as compact value chips, so that rule cards are easy to scan.
43. As a desktop user, I want to expand a rule to inspect its canonical JSON, so that advanced details remain available without cluttering the card.
44. As a desktop user, I want to enable, disable, and delete field parameter breakpoints, so that I can manage Agent-created rules locally.
45. As a desktop user, I want command breakpoint creation to continue working, so that the refactor does not regress interface-level debugging.
46. As a maintainer, I want one matcher per backend reused by runtime and explanation paths, so that the same condition cannot produce conflicting results.
47. As a maintainer, I want Java and Flask to consume the same behavioral test vectors, so that cross-backend parity is continuously verified.
48. As a maintainer, I want one canonical conditions representation in storage, so that old matching columns and compatibility branches can be removed.
49. As a maintainer, I want old databases and archives excluded from compatibility work, so that the unpublished codebase can adopt a clean schema.
50. As a maintainer, I want the matcher to operate on complete raw request parameters rather than previews or summaries, so that storage optimizations cannot alter breakpoint behavior.

## Implementation Decisions

- Use the project glossary terms “字段参数断点”, “字段条件集”, “基本类型”, “完全匹配”, “列表任一匹配”, “字段路径”, and “Session”. Remove user-facing legacy terms for parameter matching.
- Keep `command_only` as the interface-level mode. Replace `params_snapshot` and legacy `params_condition` with one internal `field_parameters` mode.
- Treat this work as a clean contract and storage reset. Remove old matchers, path aliases, operators, schema fields, tests, documentation, and archive compatibility. Do not build runtime migration, backup, schema-version compatibility, or automatic database-rebuild machinery.
- If implementation discovers a repository-local legacy database, delete that one explicit file and recreate it from the new schema. The current workspace inspection found no database file.
- MicroBreakpoint owns validation, normalization, persistence, runtime matching, explanation, and the Agent HTTP contract. Java and Flask must expose identical behavior.
- AteAgents owns MCP exposure. Extend the existing `declare_breakpoint` tool rather than adding a second creation tool. Preserve existing target routing and HITL protection.
- Keep MCP `match_type` values `interface` and `parameters`. Translate `parameters` to the internal `field_parameters` mode.
- For `interface`, conditions must be omitted or empty. For `parameters`, conditions must be a non-empty list.
- The canonical condition shape contains exactly `field_path`, `operator`, and `value`. Do not add `value_type`; use the JSON value type. Reject extra fields and all aliases.
- Require `operator` explicitly. The only supported operators are `eq` and `contains_any`.
- `eq` requires one basic-type expected value. Basic types are numbers, strings, and bool values; null, objects, and lists are not basic types.
- Numeric `eq` compares exact numeric value across integer and decimal representations. It does not use tolerance and does not coerce strings or bool values.
- String `eq` preserves case and whitespace. Bool `eq` accepts only actual bool values.
- `contains_any` requires a non-empty expected list whose entries are basic types. Candidate values form a set: order and duplicates do not affect semantics or rule identity, and numerically equal integer/decimal candidates collapse to one value.
- At runtime, `contains_any` requires the actual field to be a list. Actual list entries may be any JSON type, but only numbers, strings, and bool values participate in matching. Objects, nested lists, and null values are ignored.
- A `contains_any` condition matches when any participating actual value completely matches any normalized candidate. An empty actual list or a list without a matching basic value does not match.
- A field condition set has at least one condition. Each `field_path` appears at most once, condition order is irrelevant, and all conditions use AND semantics.
- Separate field parameter rules on the same target use OR semantics. Static OR expressions are not part of the condition schema.
- Field paths are relative to the request `params` object and never include request/response scope prefixes.
- Field paths use non-empty dot-separated object segments. Reject leading, trailing, or repeated dots; JSONPath syntax; array indices; and keys requiring dot or bracket escaping.
- Do not inject `slotId` or `slotKey` into the match root and do not store a separate slot filter for field parameter rules. Rules apply to all slots for the target object and command.
- Match only the complete original request `params` object available during the before-call lifecycle. Never match against summaries, previews, hashes, truncated content, or payload storage artifacts.
- Declaration validation is strict. Runtime data mismatches are safe non-matches: missing paths, non-object intermediate nodes, unsupported actual types, and non-list values for `contains_any` must not throw or affect the business call.
- Validation errors use stable structured data containing an error code, condition index, field, reason, and allowed values where relevant. MCP validates first; both backends independently enforce the same contract.
- Build one pure field-condition matcher in Flask and one in Java. Runtime pause decisions, latest-call observations, and match explanations in each backend must reuse that backend's matcher rather than duplicate logic.
- Store one deterministic normalized `conditions_json` value on each breakpoint row. Remove old snapshot, fingerprint, payload-reference, condition-field, and legacy condition columns used only by previous parameter matchers.
- Normalize condition order by field path and normalize `contains_any` candidate sets before persistence and identity checks. Use the canonical conditions representation in the database uniqueness rule.
- Rule identity consists of Session, business object, command, internal match mode, and normalized conditions. Display names and source reasons do not participate in identity.
- An identical declaration reuses the existing rule identifier. If the existing rule is disabled, redeclaration re-enables it. A different normalized condition set creates a separate rule.
- Interface-level and field-parameter modes are mutually exclusive for the same Session, object, and command. Creating or enabling one mode disables enabled rules of the other mode without deleting them. Multiple field parameter rules remain enabled together.
- When multiple field parameter rules match the same call, evaluate in creation order. The first match is the sole pause reason and the only rule whose hit count increases.
- Field parameter rules use continuous hit behavior only. Every matching call pauses until the rule is disabled, deleted, or removed with its Session. Do not expose once-only or hit-count-trigger options in this scope.
- Preserve Session lifecycle semantics: omitting `session_id` selects the current Session; no current Session is an error; clearing call records preserves rules; clearing or deleting the Session removes its rules.
- Allow declaration before an interface or call has been observed. Observation state is advisory and never blocks arming a valid rule.
- Return the stable rule identifier and armed status plus the complete normalized rule, whether it was reused or re-enabled, and identifiers of interface-level rules disabled by the operation.
- Enrich declaration results with a bounded target observation for the current Session: interface summary, call count, last observation time, and the latest relevant call's per-condition field presence, actual type, bounded preview, and would-match result.
- If there is no observed call, return an explicit unobserved state while keeping the rule armed. Do not scan or return all call history during declaration.
- Keep the generic breakpoint API capable of creating field parameter rules, but route it through exactly the same normalization and validation service as the Agent API.
- Require Agent-generated field paths and JSON value types to have evidence from the user, the MicroBreakpoint knowledge base, or observed calls. Agent instructions must prohibit guessing either one.
- Keep the existing HITL boundary for `declare_breakpoint`. Show the target and normalized conditions in the approval card and do not add a redundant prose confirmation.
- The desktop does not create or edit field parameter rules in this scope. Remove the legacy parameter-snapshot creation action while preserving command breakpoint creation.
- Display field parameter rules as structured condition rows under an “all conditions” group. Use concise labels for equality and list-any matching, render list candidates and bool values as compact chips, and place canonical JSON in an expandable detail view.
- Desktop management continues to support list, enable, disable, and delete operations, plus hit count and recent hit information.
- Do not include future request or response modification functionality in this specification. The pure field-path grammar must not embed request/response prefixes.

## Testing Decisions

- Test observable behavior through public contracts rather than private helper structure. A passing test must demonstrate what rule was accepted, whether a real before-call interaction paused, what rule identity was recorded, and what explanation was returned.
- Use the MicroBreakpoint Agent HTTP lifecycle as the primary high-level seam: declare or reuse a rule, submit calls with complete request parameters, observe continue/pause behavior, query the stored rule, request a match explanation, and exercise enable/disable/delete lifecycle.
- Run equivalent lifecycle scenarios against the Flask application test client and the Spring Boot integration environment.
- Maintain one shared set of JSON behavioral vectors consumed by Java and Flask tests. Vectors must cover normalization, validation, exact matching, list-any matching, per-condition reason codes, and overall AND results.
- Cover numeric equality across integer and decimal forms, numeric inequality, string case and whitespace, bool strictness, and prohibited cross-type coercion.
- Cover valid deep object paths, missing fields, non-object intermediate nodes, invalid path syntax, unsupported array traversal, and non-object top-level params.
- Cover multi-condition AND success and failure, duplicate field-path rejection, condition-order-independent identity, and empty condition rejection for parameter rules.
- Cover `contains_any` with reordered and duplicate candidates, mixed basic types, numerically equivalent candidates, empty actual lists, no overlap, actual non-list values, and actual lists containing ignored objects, nested lists, or nulls.
- Cover strict schema errors for missing operators, old aliases, unknown fields, unsupported operators, invalid expected values, and invalid candidate lists. Assert stable structured error fields rather than only message text.
- Cover interface-level regression behavior: interface rules accept empty conditions, continue to pause every matching target call, and are not affected by parameter-only validation.
- Cover mode mutual exclusion in both directions and verify that conflicting rules are disabled rather than deleted.
- Cover multiple enabled field rules, creation-order winner selection, single pause identity, and hit-count updates only on the winning rule.
- Cover idempotent declaration, candidate/condition normalization, rule reuse, and re-enabling a disabled identical rule.
- Cover declaration against observed and unobserved targets. Verify that observation information never changes whether a valid rule is armed.
- Cover declaration response content: normalized conditions, side effects, interface summary, latest-call condition observations, bounded previews, and unobserved state.
- Cover Session lifecycle: explicit/current Session selection, missing current Session error, record-only clearing preserving rules, and Session deletion removing rules.
- Cover the no-slot contract by showing that identical business params match across different synthetic slot values and that slot fields are not available as virtual paths.
- Cover continuous hit behavior across repeated matching calls and verify that continue does not disable the rule.
- Test the AteAgents MCP tool as the second high-level seam. Assert the generated tool schema, conditional validation, canonical HTTP projection, normalized response propagation, structured errors, and preservation of the existing HITL-protected tool registration.
- Test Agent-facing guidance and knowledge references so that parameter declarations use canonical field names and types from evidence and do not emit legacy aliases or unsupported operators.
- Test the desktop only for presentation and management behavior: field parameter naming, “all conditions” grouping, structured condition rows, value chips, expandable JSON, and enable/disable/delete actions. Do not duplicate matcher behavior in UI tests.
- Remove or rewrite tests that assert `params_snapshot`, legacy `params_condition`, slot filtering, old operators, old path prefixes, or old storage fields.
- Run the relevant full Flask and Java test suites after focused contract tests. Run AteAgents MCP and V3 contract tests without modifying or staging unrelated existing worktree changes.

## Out of Scope

- Modifying business-interface request parameters.
- Modifying business-interface response parameters.
- Desktop creation or editing of field parameter rules.
- OR expression trees inside one rule.
- Array indices, JSONPath, wildcard paths, escaped dotted keys, or nested-list traversal.
- Whole-list equality, contains-all, subset, prefix, range, regex, inequality, comparison, existence, or string-contains operators.
- Null as an expected condition value.
- Once-only, Nth-hit, hit-limit, or automatic-disable policies for field parameter rules.
- Global rules spanning Sessions, multiple business objects, or multiple commands.
- Synthetic slot matching through `slotId` or `slotKey`.
- Migration or compatibility for old parameter rules, databases, archives, API aliases, operators, or user-interface terminology.
- Returning all historical calls or full unbounded parameter payloads in declaration results.

## Further Notes

- The feature spans two repositories: MicroBreakpoint supplies the authoritative runtime contract and both backend implementations; AteAgents supplies the MCP tool schema, Agent guidance, HITL presentation, and HTTP adapter.
- The established interface-level command breakpoint behavior remains a required regression boundary throughout the refactor.
- The project glossary and architecture decisions created during design are authoritative for terminology and the clean-reset boundary.
- This specification is marked `ready-for-agent`; implementation can be decomposed into cross-repository tracer-bullet tickets without another requirements interview.
