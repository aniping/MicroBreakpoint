# AGENTS.md instructions for I:\ai\cc\micro-breakpoint

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

When changing debugger backend behavior or API contracts, keep the Java backend
(`java-debugger/`) and legacy Flask backend (`python-debugger/app/`) behavior in
sync unless the user explicitly scopes the task to only one backend.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

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

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
