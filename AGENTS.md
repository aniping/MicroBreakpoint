# AGENTS.md instructions for I:\ai\cc\micro-breakpoint

禁止批量删除文件或目录。
不要使用：
- `del /s`
- `rd /s`
- `rmdir /s`
- `Remove-Item -Recurse`
- `rm -rf`

需要删除文件时，只能一次删除一个明确路径的文件。
正确示例：

```powershell
Remove-Item "D:\path\to\file.txt"
```

如果需要批量删除文件，应停止操作，并向用户请求，让用户手动删除。

项目使用 Git 进行管理，新项目创建仓库注意补全 `.gitignore` 文件，不要提交与项目无关的文件。
每完成一次任务，使用中文进行 commit 提交，commit 描述要规范，清晰描述标题和修改的内容摘要。

Python 项目应该使用 conda 进行环境管理，全新项目由你新建环境。
项目环境从 AGENTS.md 中读取，不知道项目对应的环境时，向用户询问。
安装 Python 依赖失败时，立即停止，向用户寻求帮助。

改完代码要记得更新项目 README.md 文档

## Python 环境

本项目 conda 环境名：

```text
micro-breakpoint
```
