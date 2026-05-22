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
2. 打开桌面端，进入“历史会话”，点击“新建 Session”。
3. 点击“开始调试”。
4. 通过脚本、接口工具或真实业务流量触发 Java Demo 接口。
5. 在“调用记录”和“已发现接口”中查看当前 Session 的动态记录。
6. 从已发现接口或调用记录创建断点。
7. 再次触发同一业务接口，调用状态应变为 `paused`。
8. 点击“继续执行”或“继续全部”后 Java 请求恢复，状态变为 `finished`。
9. 点击“停止调试”后，新的 Java before-call 会直接放行并且不会新增调试数据。

注意：记录模式已经移除。Python 后端的新接口为 `/api/sessions`、`/api/debug/start`、`/api/debug/stop` 和 `/api/debug/reset`；桌面端不再提供 Java 调用页，Java 请求应由外部脚本、接口工具或真实业务系统触发。
