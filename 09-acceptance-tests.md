# 验收测试流程

## 1. 启动

### 启动 Python Flask 后端

```text
cd python-debugger
pip install -r requirements.txt
python run_backend.py
```

### 启动 Python 桌面端

```text
cd python-debugger
python run_desktop.py
```

### 启动 Java Demo

```text
cd java-demo
mvn spring-boot:run
```

## 2. Java 服务连接测试

在桌面端打开“Java 调用”Tab。

确认 Java 服务地址为：

```text
http://127.0.0.1:8080
```

点击“测试连接”。

预期：

```text
返回 pong
```

## 3. 记录发现验收

步骤：

```text
1. 点击“开始记录”
2. 打开“Java 调用”Tab
3. 点击“调用 initialize”
4. 点击“调用 control-create”
5. 点击“调用 control-start”
6. 打开“调用记录”Tab
```

预期：

```text
至少 3 条调用记录
包含 instrumentInitialize
包含 instrumentControl
所有记录最终状态为 finished
```

继续：

```text
7. 打开“已发现接口”Tab
```

预期：

```text
出现 instrumentInitialize
出现 instrumentControl
instrumentControl 调用次数至少为 2
```

最后：

```text
8. 点击“停止记录”
```

预期：

```text
状态变为 idle
```

## 4. 方法断点验收

步骤：

```text
1. 打开“已发现接口”Tab
2. 选择 instrumentControl
3. 点击“对此接口设置断点”
4. 打开“断点管理”Tab
```

预期：

```text
出现 instrumentControl 断点
enabled=true
hitMode=always
```

继续：

```text
5. 点击“开始调试”
6. 打开“Java 调用”Tab
7. 点击“调用 control-create”
```

预期：

```text
Java 请求被卡住
调用记录中出现 status=paused
```

继续：

```text
8. 在调用记录中点击“继续执行”
```

预期：

```text
Java 请求返回
调用记录状态变为 finished
```

## 5. 条件断点验收

步骤：

```text
1. 从一条 cmdName=create 的调用记录创建条件断点
2. 条件字段选择 cmdName
3. 点击“开始调试”
4. 打开“Java 调用”Tab
5. 点击“调用 control-start”
```

预期：

```text
不暂停
请求正常返回
```

继续：

```text
6. 点击“调用 control-create”
```

预期：

```text
请求暂停
调用记录 status=paused
点击继续后恢复
```

## 6. 异常记录验收

步骤：

```text
1. 点击“开始记录”或“开始调试”
2. 打开“Java 调用”Tab
3. 点击“调用 error”
4. 打开“调用记录”Tab
```

预期：

```text
出现 instrumentControl 调用
状态为 exception
显示 exceptionType
显示 exceptionMessage
```

## 7. 停止调试释放等待验收

步骤：

```text
1. 设置 instrumentControl 方法断点
2. 点击“开始调试”
3. 点击“调用 control-create”，让请求暂停
4. 不点击继续执行
5. 点击“停止调试”
```

预期：

```text
所有 paused 调用被释放
Java 请求返回
状态变为 idle
```

## 8. Python 不在线容错验收

步骤：

```text
1. 停止 Python Flask 后端
2. 保持 Java Demo 运行
3. 浏览器直接访问 http://127.0.0.1:8080/api/demo/control?cmdName=create
```

预期：

```text
Java 请求仍然正常返回
不会因为 Python 不在线而失败
```
