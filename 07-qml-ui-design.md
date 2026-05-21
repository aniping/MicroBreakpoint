# QML 界面设计

## 1. 主窗口

标题：

```text
MicroBreakpoint - Java 微服务接口断点调试器
```

建议尺寸：

```text
1200 x 800
```

布局：

```text
顶部工具栏
状态栏
Tab 页面
左侧列表
右侧详情
```

## 2. 顶部工具栏

按钮：

```text
开始记录
停止记录
开始调试
停止调试
刷新
继续全部
清空筛选
```

按钮状态：

```text
Idle:
  开始记录可用
  开始调试可用
  停止记录不可用
  停止调试不可用

Recording:
  停止记录可用
  开始记录不可用
  开始调试不可用
  停止调试不可用

Debugging:
  停止调试可用
  继续全部可用
  开始记录不可用
  停止记录不可用
```

## 3. 状态栏

展示：

```text
当前状态
当前 sessionId
当前模式
调用总数
已发现接口数
断点数量
暂停中数量
```

示例：

```text
状态：调试中 | Session: debug-001 | 调用: 8 | 接口: 2 | 断点: 1 | 暂停: 1
```

## 4. Tab 页面

必须包含：

```text
调用记录
已发现接口
断点管理
历史会话
Java 调用
```

## 5. 调用记录 Tab

列表字段：

```text
调用序号
服务名
方法名
中文描述
状态
耗时
线程名
调用时间
是否命中断点
```

支持：

```text
搜索
状态过滤
方法过滤
服务过滤
排序
分页
```

右侧详情展示：

```text
callId
sessionId
callIndex
serviceName
className
methodName
displayName
description
threadName
status
args JSON
parameterMeta JSON
result JSON
exceptionType
exceptionMessage
costMs
breakpointId
createdAt
updatedAt
```

操作按钮：

```text
继续执行
按方法创建断点
按本次参数创建断点
复制入参
复制返回值
刷新详情
```

继续执行只在 paused 状态可用。

## 6. 已发现接口 Tab

列表字段：

```text
服务名
类名
方法名
中文名
调用次数
成功次数
异常次数
平均耗时
最后调用时间
```

右侧详情：

```text
interfaceId
sessionId
serviceName
className
methodName
displayName
description
parameterSchema
sampleArgs
callCount
successCount
exceptionCount
avgCostMs
maxCostMs
minCostMs
firstSeenAt
lastSeenAt
```

操作按钮：

```text
对此接口设置断点
查看相关调用
复制接口信息
```

## 7. 断点管理 Tab

列表字段：

```text
启用状态
断点名称
服务名
类名
方法名
条件
命中模式
命中次数
来源
创建时间
```

操作：

```text
新增断点
启用
禁用
删除
编辑条件
```

## 8. 历史会话 Tab

列表字段：

```text
sessionId
mode
serviceName
开始时间
结束时间
调用次数
发现接口数
异常数
备注
```

操作：

```text
打开会话
删除会话
导出会话
```

## 9. Java 调用 Tab

这是本项目闭环的关键页面。

必须包含：

```text
Java 服务地址输入框
默认值：http://127.0.0.1:8080
测试连接按钮
调用 initialize 按钮
调用 control-create 按钮
调用 control-start 按钮
调用 control-stop 按钮
调用 error 按钮
自定义 instType 输入框
自定义 cmdName 输入框
自定义 slotId 输入框
自定义调用按钮
调用结果展示区
```

按钮对应请求：

```text
测试连接 -> GET /api/demo/ping
initialize -> GET /api/demo/initialize
control-create -> GET /api/demo/control?instType=VNA&cmdName=create&slotId=1
control-start -> GET /api/demo/control?instType=VNA&cmdName=start&slotId=1
control-stop -> GET /api/demo/control?instType=VNA&cmdName=stop&slotId=1
error -> GET /api/demo/error
自定义调用 -> GET /api/demo/control?instType={instType}&cmdName={cmdName}&slotId={slotId}
```

用户典型操作：

```text
点击开始记录
进入 Java 调用 Tab
点击 initialize / control-create
回到调用记录 Tab 查看记录
回到已发现接口 Tab 查看动态发现的接口
```
