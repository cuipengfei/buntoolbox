---
name: upgrade-versions
description: >
  当用户要求检查或应用 buntoolbox 的 Docker/WSL 工具版本更新、bump
  docker/layers 版本号、commit/push 版本升级、观看 GitHub Actions
  镜像构建、或在 CI 后验证 test-image 结果时使用。触发语包括
  "check updates for both wsl and docker"、"version upgrade checks"、
  "upgrade all for docker"、"commit push and watch gh action"、
  "test image tests in the build"、"升级版本检查"、"docker 和 wsl 都查一下"。
---

# 升级版本检查 + CI 验证

## 概述

buntoolbox 仓库的标准升级闭环：查 Docker 镜像依赖与 WSL 本机工具版本 →
（可选）升级 → commit/push → 盯 GitHub Actions → 验证 image test 全绿。

权威来源顺序（高到低）：

1. `AGENTS.md` 的 `WORKFLOW: 新增工具 / 版本升级（标准流程）`
2. 本 skill
3. 历史 session 做法（仅参考，不能覆盖前两者）

## 何时用

- 用户说"查 docker 和 wsl 更新"、"升级版本"、"commit push 看 gh action"
- 需要确认 CI 构建后 image test 是否真的跑过且 PASS
- bump `docker/layers/*.env` 版本号

## 何时不用

- 非 buntoolbox 仓库
- 只问某个工具官网最新版（直接查官网，不走本流程）
- 一般依赖审计、不涉及镜像构建

## 模式门闩（必读）

每次进入流程前，先识别用户授权模式：

### 模式 1：full-auto

用户明说"full auto"、"全自动"、"一路做到底"、"check upgrade commit push watch 一条龙"。

允许：check → upgrade → commit → push → watch CI → verify test-image，
阶段间不停点确认。仍受红线约束（不本地 build、不越 scope）。

### 模式 2：step-by-step（默认）

未明说 full-auto 时默认此模式。每个 major step 前需用户授权：

- check（只读，默认允许）
- upgrade（改文件，需授权）
- commit + push（需授权）
- watch CI + verify test-image（需授权）

**判断规则**：模糊时按 step-by-step 走，不要擅自升级到 full-auto。

## 阶段

### A. Check（只读，默认允许）

1. `git status --short --branch` —— 记录起始工作区状态
2. `./scripts/check-versions.sh` —— Docker 镜像依赖版本
3. `./scripts/check-wsl-versions.sh` —— WSL 本机工具版本
4. 汇总表：Tool / Current / Latest / Side(Docker|WSL) / Status

输出后**停**。无升级授权不改任何文件。

### B. Upgrade（需授权）

触发语例：`upgrade all for docker`、`upgrade these`、`把这几个 bump 一下`。

规则：

1. Docker bump：只改对应 `docker/layers/*.env`
2. WSL bump：按检查脚本/官方源升级本机，不动无关工具
3. 按 `AGENTS.md` 同步：check 脚本、test 脚本、README、image-release.txt
4. **禁止本地 `docker build`** —— 让 GitHub Actions 做
5. 改完重跑两 check 脚本，确认目标项到预期状态
6. variant 边界：默认假设工具同时出现在 latest/i3/kde；只某 variant 用的工具要在 Dockerfile/README/test 明确

### C. Commit + push（需授权）

1. 只 stage 本次 bump 相关文件（`git add <具体文件>`，不要 `git add -A`）
2. conventional commit：`chore: bump <工具> <旧> -> <新>`
3. `git push`
4. 记录 commit SHA

### D. Watch CI + verify test-image（需授权）

1. `gh run list --commit <sha> --limit 5 --json databaseId,name,status,conclusion,url`
2. `gh run watch <id> --exit-status`
3. **解析 job/step**，尤其 image test 相关 step 的 PASS/FAIL —— 不要只看 workflow 绿就完
4. **必须读取 GitHub Actions job/step 的原始日志**，不能只看 run conclusion、job conclusion 或摘要。
   - 构建日志必须明确出现本次每个升级项的实际版本：工具名、目标版本。
   - `test-image` 必须有实际日志输出；必须从日志中确认镜像测试命令、测试项及 PASS/FAIL 结果。
   - 日志缺少任一升级项版本，或缺少 `test-image` 实际测试输出，均视为未完成，即使 workflow 为绿色。
   - 优先使用 `gh run view <run-id> --job <job-id> --log`；必要时用 `gh api repos/{owner}/{repo}/actions/jobs/{job-id}/logs` 获取原始日志。
   - 最终报告必须列出：run URL、job/step 名、升级项及日志中的版本证据、`test-image` 日志关键行、PASS/FAIL 计数。
5. CI 发布后按需跑：
   - master push：`./scripts/test-image.sh --variant latest --image cuipengfei/buntoolbox:latest`
   - `v*` tag 发布后才加 i3/kde
6. 失败：贴 run URL + 失败 job/step + 原始日志关键行；不宣称完成

## 输出合同

每次阶段结束输出：

- 当前阶段（A/B/C/D）
- 模式（full-auto / step-by-step）
- 改动文件清单（或"未改文件"）
- commit SHA / push 结果 / run URL（若到该阶段）
- 证据命令（实际跑过的）
- blocked / 未验证项

## 常见失败模式（历史 session 踩过的坑）

| 坑 | 真相 | 对策 |
|---|---|---|
| 摘要层把 `current != latest` 显示成 up-to-date | 脚本逻辑：`current == latest` 才 up-to-date；不等就有更新 | 读脚本原始输出，不信二手摘要 |
| WSL local > repo target 显示 "update available" | 本机版本高于仓库 target，不等于本机旧 | 比对版本值，不迷信状态文字 |
| `fetch failed`（如 httpie）被当成 up-to-date | fetch 失败时无法判断 | 单独标 "fetch failed"，不装成 up-to-date |
| push 到 master 后期望 i3/kde 已发布 | master 只发 latest；i3/kde 要 `v*` tag | 按 AGENTS.md variant 规则 |
| CI 总绿就宣称 test-image 全过 | workflow 绿 ≠ test step PASS | 必须解析 test step 的 PASS/FAIL |
| 把"检查通过"说成"已升级" | check 是只读 | 区分 check / upgrade 语义 |

## 红线

- 无授权：不改 env、不升级本机、不 commit、不 push
- 永不本地 `docker build`
- 不把"检查通过"说成"已升级"
- 不把 CI 总绿且未读 test step 说成 test-image 全过
- 不扩 scope 到无关重构
- 未验证就标"未验证"，不补脑

## 验证清单（宣称完成前）

- [ ] 两 check 脚本都跑过，退出码已知
- [ ] 若 upgrade：改的 env 文件列出，重跑 check 确认
- [ ] 若 push：commit SHA 记录
- [ ] 若 watch CI：run URL + 关键 step 状态（不只 workflow conclusion）
- [ ] 若 verify test-image：实际命令 + PASS/FAIL 计数
- [ ] 未完成项明确标注，不藏
