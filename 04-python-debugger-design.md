# Python 断点程序开发说明

## 1. 技术栈

```text
Python 3.10+
Flask
Flask-CORS
SQLite
PySide6
QML
requests
```

Flask 端口：

```text
5050
```

## 2. 目录结构

```text
python-debugger/
├── README.md
├── requirements.txt
├── run_backend.py
├── run_desktop.py
├── app/
│   ├── __init__.py
│   ├── api/
│   │   ├── session_api.py
│   │   ├── call_api.py
│   │   ├── interface_api.py
│   │   ├── breakpoint_api.py
│   │   └── state_api.py
│   ├── db/
│   │   └── database.py
│   ├── models/
│   │   └── schema.sql
│   ├── services/
│   │   ├── state_service.py
│   │   ├── session_service.py
│   │   ├── call_record_service.py
│   │   ├── interface_discover_service.py
│   │   ├── breakpoint_service.py
│   │   └── wait_manager.py
│   └── utils/
│       ├── json_utils.py
│       └── time_utils.py
└── desktop/
    ├── main.py
    ├── bridge.py
    └── qml/
        ├── Main.qml
        ├── Toolbar.qml
        ├── CallRecordTab.qml
        ├── InterfaceTab.qml
        ├── BreakpointTab.qml
        ├── SessionTab.qml
        ├── JavaCallTab.qml
        └── DetailPanel.qml
```

## 3. 后端状态

### Idle

```text
recording=false
debugging=false
mode=idle
```

### Recording

```text
recording=true
debugging=false
mode=record
```

### Debugging

```text
recording=true
debugging=true
mode=debug
```

## 4. 服务模块

### StateService

维护当前状态：

```text
recording
debugging
mode
currentSessionId
callCount
discoveredInterfaceCount
breakpointCount
pausedCount
```

### SessionService

负责：

```text
开始记录
停止记录
开始调试
停止调试
创建 session
结束 session
查询历史 session
```

### CallRecordService

负责：

```text
创建调用记录
更新调用结果
更新调用状态
查询调用列表
查询调用详情
搜索
过滤
排序
```

### InterfaceDiscoverService

负责：

```text
根据 before-call 创建或更新 discovered_interface
更新接口调用次数
合并参数结构
保存样例参数
统计成功、异常、耗时
```

### BreakpointService

负责：

```text
创建断点
删除断点
启用断点
禁用断点
查询断点
判断调用是否命中断点
维护命中次数
```

### WaitManager

负责：

```text
创建等待对象
等待指定 callId
继续指定 callId
继续全部
超时释放
清理等待对象
```

必须线程安全。

## 5. before-call 处理逻辑

```text
1. 获取当前状态
2. 如果 recording=false，返回 continue，不记录
3. 如果 recording=true，创建 call_record
4. 创建或更新 discovered_interface
5. 如果 debugging=false，返回 continue
6. 如果 debugging=true，判断断点
7. 未命中断点，返回 continue
8. 命中断点，创建 wait event，状态设为 paused，返回 pause
```

## 6. after-call 处理逻辑

```text
1. 根据 callId 查找调用记录
2. 更新 result_json、success、exception、cost_ms
3. success=true 状态为 finished
4. success=false 状态为 exception
5. 更新 discovered_interface 统计信息
```

## 7. 桌面端 Bridge

Bridge 负责让 QML 调用：

```text
Python Flask API
Java Demo REST API
```

Java Demo REST API 默认地址：

```text
http://127.0.0.1:8080
```

Bridge 必须提供：

```text
startRecord
stopRecord
startDebug
stopDebug
loadState
loadCalls
loadInterfaces
loadBreakpoints
continueCall
continueAll
createBreakpointFromInterface
createBreakpointFromCall
javaPing
javaInitialize
javaControlCreate
javaControlStart
javaControlStop
javaError
javaCustomControl
```
