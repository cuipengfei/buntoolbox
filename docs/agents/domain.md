# Domain docs

本仓库采用 **single-context** 布局。

读取约定：

1. 先读仓库根目录 `CONTEXT.md`（若存在）。
2. 再读 `docs/adr/` 下与当前任务相关的 ADR（若存在）。

当前仓库现状（初始化时）：

- `CONTEXT.md` 不存在
- `CONTEXT-MAP.md` 不存在
- `docs/adr/` 不存在

执行规则：

- 相关文件缺失时，技能可继续执行，不强制先创建。
- 后续若演进为 multi-context，请新增 `CONTEXT-MAP.md` 并更新本文件。

