---
name: upgrade-versions
description: >
  当用户要求检查或应用 buntoolbox 的 Docker/WSL 工具版本更新、bump
  docker/layers 版本号、commit/push 版本升级、观看 GitHub Actions
  镜像构建，或验收对应 push 的 CI `test-image` 日志时使用。触发语包括
  "check updates for both wsl and docker"、"version upgrade checks"、
  "upgrade all for docker"、"commit push and watch gh action"、
  "test image tests in the build"、"升级版本检查"、"docker 和 wsl 都查一下"。
  也适用于诊断版本 checker 的 `fetch failed`、远端抓取失败或需要重试版本检查的请求。
---

# 升级版本检查 + CI 验证

## 概述

buntoolbox 的标准闭环：查 Docker/WSL 版本 →（授权时）升级 → commit/push → 等 GitHub Actions → 读取 CI 原始 `test-image` 日志 → 完成。

CI 已成功推送镜像、且 CI 原始 `test-image` 日志验收完成，就是完成。默认禁止本机运行 `test-image.sh`。

权威来源顺序：

1. `AGENTS.md` 的“新增工具 / 版本升级（标准流程）”
2. 本 skill
3. 历史 session（只能参考）

## 模式

### full-auto

用户明说“full auto”“全自动”“一路做到底”或“check upgrade commit push watch 一条龙”时，自动连续执行 A→D。

### step-by-step（默认）

每个 major step 前需授权：

- check：只读，默认允许；
- upgrade：改文件；
- commit + push；
- watch CI + 日志验收。

## A. Check

运行：

```bash
git status --short --branch
./scripts/check-versions.sh
./scripts/check-wsl-versions.sh
```

输出表必须分开写 Docker、WSL。

规则：

- `current != latest` 不自动等于本机旧；
- WSL 本机版本高于 repo target 时，不降级；
- fetch failed 单列为未验证；
- 无升级授权时，不改文件。

### Fetch failure / incomplete run handling

- 等待每个 checker 进程到达终端状态后再汇总；中间输出不是结果。
- 记录两个 checker 的退出码。若某行是 `fetch failed`，不得把它当成
  `up-to-date` 或 `update available`。
- 立即重跑受影响的 checker 一次。重试成功时，采用第二次结果，并说明首次
  是临时抓取失败；重试仍失败时，将该项保留为“未验证”，排除出升级列表。
- 若 checker 将 stderr 丢弃，读取对应 fetch 函数和 URL，使用等价的
  `curl --fail --show-error` 定向探针，保留原始 stderr、URL 和退出码；不要
  用空值猜版本。
- `-4`/IPv4 只能作为网络路径诊断对照。只有 IPv4 成功时，报告传输路径差异，
  不要静默修改 checker 或把诊断选项当成永久修复。

## B. Upgrade

规则：

1. Docker 版本只改对应 `docker/layers/*.env`。
2. WSL 只改用户明确要求升级的本机工具。
3. 按 `AGENTS.md` 同步需要的 checker、test、README 和 metadata。
4. 禁止本地 `docker build`。
5. 改后重跑两份 checker。
6. 默认工具覆盖 `latest`、`i3`、`kde`；仅某 variant 使用时，必须明确边界。

## C. Commit + push

1. 只 stage 本次变更文件；不用 `git add -A`。
2. 用 conventional commit。
3. `git push`。
4. 记录 commit SHA。

## D. GitHub Actions 日志验收

1. 找到该 commit 的 run：

```bash
gh run list --commit <sha> --limit 5 \
  --json databaseId,name,status,conclusion,url,headSha
```

2. 等待完成：

```bash
gh run watch <run-id> --exit-status
```

3. 读取成功 job 的原始日志：

```bash
gh run view <run-id> --job <job-id> --log
```

必要时使用 GitHub Actions job log API。

4. **完成门槛：**

   - 对应 push 的 workflow 成功；
   - 镜像 build-and-push step 成功；
   - 原始日志出现本次每个升级项的实际版本；
   - 原始日志出现 `test-image` 的实际输出和 PASS/FAIL 汇总。

### 逐项 Docker 升级验收（强制）

对本次修改的每一个 Docker 工具单独检查并单独报告，不得只写
“Docker 升级已通过”：

1. 在成功 job 的**原始日志**中搜索工具名和目标版本。
2. 判定该工具的日志状态：
   - 目标版本出现，且该工具对应的 `test-image` 检查为 `PASS`：`OK`；
   - 目标版本出现但检查为 `FAIL`、版本不正确，或构建/推送相关步骤失败：`失败`；
   - 工具名或目标版本未出现：`未验证（日志未出现）`；
   - 版本出现但没有对应的通过/失败检查：`未验证（缺少检查结果）`。
3. workflow 总体成功不能替代逐项检查。任何一个 Docker 工具不是 `OK` 时，
   不得把整个 Docker 升级包报告为完成。

最终回复必须包含下列表格，逐行覆盖本次每个 Docker 升级项：

```text
| Docker 工具 | 目标版本 | 原始 CI 日志是否出现 | 对应检查 | 结论 |
| Bun         | 1.4.1    | 出现                  | PASS     | OK   |
```

“原始 CI 日志是否出现”只能填写“出现”或“未出现”；“对应检查”填写实际
`PASS`、`FAIL` 或“无结果”。不要用 workflow 绿灯、构建成功或推断结果替代
该列。未出现或无检查结果必须明确写出来。

5. **满足完成门槛后立即停止。**

   - 不 pull 发布镜像；
   - 不运行 `./scripts/test-image.sh`；
   - 不启动或修复本机 Docker Desktop；
   - 不以“再确认一次”为理由追加本机验证。

   只有用户明确说“本机复验”时，才允许运行本机 `test-image.sh`。

6. master push 只构建和发布 `latest`。`i3` / `kde` 未运行是预期，不是遗漏；只有 `v*` tag 或对应 workflow_dispatch 才覆盖它们。

## 最终输出合同

最终回复必须从 GitHub Actions 原始日志中确认本次升级项确实进入镜像，并且
必须逐项告诉用户：每个 Docker 升级项在日志中是否出现；如果出现，对应检查
是 `PASS` 还是 `FAIL`；最后给出该项 `OK`、`失败` 或“未验证”的结论。
不要粘贴整份原始日志；只展示本次 push 改动包的版本变化和逐项检查结果。

| 必填项 | 必须说明 |
| --- | --- |
| Push | commit SHA、提交内容 |
| CI | run URL、job 名、workflow 结论 |
| 覆盖范围 | 本次 push 实际构建/发布的 variant；未覆盖 variant 是否预期 |
| 本次版本变化 | 仅列本次 push 修改的包：`包名 | 旧版本 | 新版本`；新版本必须已在原始 CI 日志中确认 |
| Docker 逐项验收 | 每个 Docker 包都列出：目标版本、日志是否出现、对应检查结果、最终结论 |
| 本机复验 | 默认“未运行；CI 日志验收即完成”；若用户明确要求才说明本机结果 |

不要粘贴完整原始日志或逐行测试输出；但必须在上述逐项表格中展示每个
Docker 工具对应的 `PASS`、`FAIL` 或“无结果”，以及最终结论。`BUNTOOLBOX_TESTS_COMPLETED`
等整体完成标记仍属于内部验收证据。

失败或未验证时必须给：run URL、失败/缺失的 job 或 step、原始日志关键行。
不得把未出现、无检查结果或 `FAIL` 写成 `OK`，也不得宣称整个升级包完成。

## 红线

- 无授权：不改 env、不升级本机、不 commit、不 push。
- 永不本地 `docker build`。
- 默认永不本机运行 `test-image.sh`。
- 不把 checker 通过说成已升级。
- 不把 workflow 总绿当作 `test-image` 通过。
- 不读原始 job 日志，不得宣称 CI 验收完成。
- 不扩 scope 到无关重构。

## 验证清单

- [ ] 两份 checker 都运行，退出码已知。
- [ ] 每份 checker 都已到终端状态后再汇总。
- [ ] 每个 `fetch failed` 都已重试；仍失败的项列为未验证且未进入升级列表。
- [ ] 若升级：目标 `.env` 已列出，checker 已重跑。
- [ ] 若 push：commit SHA 已记录。
- [ ] 若 watch CI：run URL、job、step 已记录。
- [ ] 原始日志已确认本次升级项版本，最终回复只列 `包名 | 旧版本 | 新版本`。
- [ ] 每个 Docker 升级项都已逐项报告日志是否出现、检查结果和 `OK`/失败/未验证结论。
- [ ] 原始 `test-image` 日志已完成内部 PASS/FAIL 验收，不粘贴其测试细节。
- [ ] 未本机运行 `test-image.sh`；除非用户明确要求本机复验。
