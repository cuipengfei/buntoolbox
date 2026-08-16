# Stack Scount 本地状态契约

## 状态位置

```text
.omx/state/stack-scount/state.json
.omx/catalog/stack-scount/candidates.md
.omx/catalog/stack-scount/rounds/
.omx/catalog/shortlist.md
```

`.omx` 是本地、非提交的工作记忆。它不是临时垃圾目录；每轮先读、后写、可追溯。

## `state.json`

必填顶层字段：

- `schema_version`
- `system`
- `baseline_artifacts`
- `seed_sources`
- `candidate_index`
- `runs`
- `next_focus`

每个候选至少有 `id`、`name`、`status`、`evidence_paths`、`last_verdict`。候选状态必须是 skill 中列出的七种之一。

每个 run 至少有 `id`、`date`、`kind`、`summary`、`report_path`。`kind` 为 `bootstrap`、`wide`、`deep-dive` 或 `refresh`。

## 写入顺序

1. 读取状态和相关 artifacts。
2. 做研究并先向用户直接报告结论。
3. 写 round report；更新 candidates ledger、shortlist（仅用户决定时）和 state。
4. 运行：

```bash
python3 .agents/skills/stack-scount/scripts/validate-state.py
```

## 旧 autoresearch 的处理

`.omx/specs/autoresearch-tool-catalog/validate.sh` 保留为旧研究的验证器和结构参考。它的 `result.json` 当前不是 Stack Scount 的完成门槛；不得为让它通过而篡改旧 state。
