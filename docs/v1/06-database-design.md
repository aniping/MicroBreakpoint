# 数据库设计

使用 SQLite。

## 1. debug_session

表示一次记录或调试会话。

字段：

```text
id TEXT PRIMARY KEY
mode TEXT
service_name TEXT
operator TEXT
start_time TEXT
end_time TEXT
recording INTEGER
debugging INTEGER
remark TEXT
created_at TEXT
updated_at TEXT
```

mode：

```text
record
debug
```

## 2. call_record

表示每一次接口调用。

字段：

```text
id INTEGER PRIMARY KEY AUTOINCREMENT
call_id TEXT UNIQUE
session_id TEXT
call_index INTEGER
service_name TEXT
class_name TEXT
method_name TEXT
display_name TEXT
description TEXT
thread_name TEXT
args_json TEXT
parameter_meta_json TEXT
result_json TEXT
success INTEGER
exception_type TEXT
exception_message TEXT
cost_ms INTEGER
status TEXT
breakpoint_id TEXT
created_at TEXT
updated_at TEXT
```

status：

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

## 3. discovered_interface

表示动态发现的接口。

字段：

```text
id TEXT PRIMARY KEY
session_id TEXT
service_name TEXT
class_name TEXT
method_name TEXT
display_name TEXT
description TEXT
parameter_schema_json TEXT
sample_args_json TEXT
first_seen_at TEXT
last_seen_at TEXT
call_count INTEGER
success_count INTEGER
exception_count INTEGER
avg_cost_ms REAL
max_cost_ms INTEGER
min_cost_ms INTEGER
created_at TEXT
updated_at TEXT
```

唯一性建议：

```text
session_id + service_name + class_name + method_name 唯一
```

## 4. breakpoint

表示断点规则。

字段：

```text
id TEXT PRIMARY KEY
name TEXT
enabled INTEGER
service_name TEXT
class_name TEXT
method_name TEXT
display_name TEXT
condition_json TEXT
hit_mode TEXT
hit_count INTEGER
source_session_id TEXT
source_interface_id TEXT
source_call_id TEXT
created_at TEXT
updated_at TEXT
```

hit_mode：

```text
always
once
hit_count
```

## 5. 参数结构

parameter_schema_json 示例：

```json
{
  "instType": {
    "name": "instType",
    "displayName": "仪表类型",
    "description": "仪表类型",
    "javaType": "java.lang.String",
    "sample": "VNA"
  },
  "cmdName": {
    "name": "cmdName",
    "displayName": "仪表操作",
    "description": "仪表操作",
    "javaType": "java.lang.String",
    "sample": "create"
  },
  "slotId": {
    "name": "slotId",
    "displayName": "槽位id",
    "description": "槽位id",
    "javaType": "int",
    "sample": 1
  }
}
```

## 6. 断点条件

condition_json 示例：

```json
{
  "cmdName": "create",
  "slotId": 1
}
```

匹配规则：

```text
断点 enabled=true
methodName 匹配
serviceName 不为空时必须匹配
className 不为空时必须匹配
condition_json 为空时直接命中
condition_json 不为空时，args 中对应字段必须全部相等
```
