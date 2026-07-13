# MicroBreakpoint

MicroBreakpoint defines debugger rules that pause selected business-command calls so developers and AI Agents can inspect and control them.

## Language

**Session**:
A debugger work context that groups business calls, discovered interfaces, and breakpoint rules. A field parameter breakpoint belongs to exactly one Session.
_Avoid_: 全局会话、永久断点范围

**字段参数断点**:
A breakpoint rule that targets a business command and pauses only when all configured parameter fields from the same request exactly match their expected values.
_Avoid_: 条件断点、参数快照断点、参数级断点

**字段条件集**:
The non-empty collection of field matches owned by one field parameter breakpoint; every field path is unique, ordering has no meaning, and all conditions are combined with AND. OR is represented by separate breakpoint rules.
_Avoid_: 条件表达式、空条件断点

**基本类型**:
A condition value category consisting only of numbers, strings, and booleans. Numbers include both integers and decimals; nulls, objects, and arrays are not basic types.
_Avoid_: 标量类型、简单类型、整数和小数作为不同类型

**完全匹配**:
A value comparison that never coerces between numbers, strings, and booleans. Integers and decimals belong to the same numeric category and match when their exact numeric values are equal; strings preserve case and whitespace, and booleans match only booleans.
_Avoid_: 字符串化比较、宽松相等、类型强制转换

**列表任一匹配**:
The `contains_any` comparison that matches when any basic-type value in an actual request list exactly matches any user-specified candidate value. Non-basic actual values are ignored; candidate values form a non-empty set of basic types where order and duplicates have no meaning.
_Avoid_: 数组相等、列表字符串匹配、列表嵌套匹配

**字段路径**:
A non-empty dot-separated identifier such as `a.b.c` that selects nested object fields relative to request parameters. It excludes request/response prefixes, JSONPath syntax, array indices, empty segments, and field names that require dot or bracket escaping.
_Avoid_: 键路径、JSONPath
