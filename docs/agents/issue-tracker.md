# Issue tracker: GitHub

本仓库的任务请求面是 GitHub Issues，统一使用 `gh` CLI 操作。

常用约定：

- 创建 issue：`gh issue create --title "..." --body "..."`
- 查看 issue：`gh issue view <number> --comments`
- 列出 issue：`gh issue list --state open`
- 评论 issue：`gh issue comment <number> --body "..."`
- 标签管理：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- 关闭 issue：`gh issue close <number> --comment "..."`

外部 PR triage 规则：

- 外部 PR **不**作为请求面（PRs as a request surface = `no`）。
- `triage` 仅处理 issue，不把外部 PR 拉入同一状态机。

