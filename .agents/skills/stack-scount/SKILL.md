---
name: stack-scount
description: 当用户要基于其个人 stack、全局 Bun/uv 工具、agents skills/lock、AGC agent configs、buntoolbox Docker/WSL 能力和既有 .omx 研究，持续寻找还会喜欢、需要或能增强总体工作方式的工具、能力和组合时使用。也用于“wide first”“neighbors/cousins/alternatives/adjacents”“继续上次 stack research”“更新 shortlist”等请求。
---

# Stack Scount

这是 `/home/cpf/code-inside/buntoolbox` 及其所有者专属的持续研究系统。不要泛化，不要为其他用户删减真实路径、命令或偏好。

## 目标

把个人 stack 变成可累积的机会地图。每轮先读本地状态，再研究增量；交付建议，不交付工具清单或 repo 改进清单。

## 固定 seed

将以下视为同一份联合 seed 的章节：

1. `bun pm ls -g`
2. `uv tool list all --show-extras`
3. `~/.agents/skills/` 与 `~/.agents/.skill-lock.json`
4. `/home/cpf/code-inside/agc` 的 agent configs
5. 当前 repo 的 Dockerfile、layers、variants
6. `scripts/check-wsl-versions.sh`
7. `.omx/catalog/`、`.omx/specs/autoresearch-tool-catalog/` 与 `.omx/state/` 的已有材料

Docker、WSL、AGC、Bun、uv、skills 都是发现输入，不是把交付缩成其中任一项改进的理由。

## 每轮流程

1. 先读 `.omx/state/stack-scount/state.json`、`.omx/catalog/stack-scount/candidates.md`、`.omx/catalog/shortlist.md` 和最近一轮报告。
2. 读状态中列出的 baseline artifacts。旧 catalog、研究、spec 和 validator 是可复用证据；不得重建或无视它们。
3. 只采集发生变化的 seed；记录新快照或证据路径。没有变化时，优先推进未探索能力簇或短名单，不重跑同一份泛搜。
4. 先宽搜：neighbors、cousins、alternatives、similars、adjacents、上下游、桥接件、跨域组合、重复和盲点。宽搜新信息衰减后，才深挖候选。
5. 每个陌生候选固定按“是什么 → 如何工作 → 实际怎么用 → 现有能力为何不等价 → verdict → 证据/边界”解释。
6. 先直接汇报结论；随后更新候选账本、round report 和 `state.json`。每次写后运行 `scripts/validate-state.py`。

## 候选生命周期

只使用 `unseen`、`seen`、`not-recommended`、`shortlisted`、`deep-dive`、`adopted`、`superseded`。

旧候选再次出现时，必须写出它此前的 verdict、本轮新增证据和 verdict 是否变化。不得把旧建议伪装成新发现。

`shortlisted` 必须同时出现在 `.omx/catalog/shortlist.md`；由用户明确保留、移除或改变状态。

## 输出

按能力簇排序，依次给出：

1. 本轮 verdict：最值得推进的候选或深挖方向。
2. 建议项：定义、机制、实际使用、seed 连接、非等价性、理由。
3. 看过但不建议：定义和排除理由。
4. 其他候选：缺哪条能改变排序的证据。
5. 状态变化：新增、升级、降级、已饱和的搜索面。

## 禁止

- 不把 catalog 当最终目的。
- 不把任务缩成 repo、Docker、WSL 或 CI 改进。
- 不以权限、控制、保守性或“少装工具”占据主叙事。
- 不把已安装等同于喜欢或常用。
- 不先扔产品名和术语。
- 不只汇报写入了哪些文件。
- 不用“各有千秋”逃避排序。
- 不覆盖 `.omx/specs/autoresearch-tool-catalog/` 的旧 state/result；Stack Scount 使用自己的 state。

详见 `references/state-contract.md`。
