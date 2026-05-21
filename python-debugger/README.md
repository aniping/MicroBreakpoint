# Python Debugger

Flask 后端端口 `5050`，桌面端使用 PySide6/QML。

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

桌面端会自动拉起 Flask 后端；`run_backend.py` 仍保留给后端单独启动和调试使用。若 `http://127.0.0.1:5050` 已经可用，桌面端会复用该后端。

## 主题与外观

桌面端支持暗色模式和亮色模式。可以通过顶部标题栏右侧的主题按钮快速切换，也可以在“设置”页的“外观”区域选择主题。

主题选择会持久化保存，重启桌面端后保持上次选择。默认主题为暗色。

## 验收主链路

1. 启动 Java Demo。
2. 打开桌面端，进入“历史会话”，点击“新建会话”。
3. 点击“开始记录”。
4. 进入“Java 调用”页，点击 `initialize`、`control-create`。
5. 在“调用记录”和“已发现接口”中查看当前会话的动态记录。
6. 点击“停止记录”，对 `instrumentControl` 设置断点。
7. 点击“开始调试”，再次调用 `control-create`，调用状态应变为 `paused`。
8. 点击“继续执行”后 Java 请求恢复，状态变为 `finished`。

注意：点击“开始记录”或“开始调试”只会切换调试器状态，不会自动调用 Java。必须在“Java 调用”页主动触发 Java Demo 接口，Java Controller 调用 Service 后，Python 后端才会收到 AOP 上报并生成调用记录和接口发现数据。
