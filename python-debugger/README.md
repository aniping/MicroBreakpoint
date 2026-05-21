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

## 验收主链路

1. 启动 Java Demo。
2. 打开桌面端，进入“历史会话”，点击“新建会话”。
3. 点击“开始记录”。
4. 进入“Java 调用”页，点击 `initialize`、`control-create`。
5. 在“调用记录”和“已发现接口”中查看当前会话的动态记录。
6. 点击“停止记录”，对 `instrumentControl` 设置断点。
7. 点击“开始调试”，再次调用 `control-create`，调用状态应变为 `paused`。
8. 点击“继续执行”后 Java 请求恢复，状态变为 `finished`。
