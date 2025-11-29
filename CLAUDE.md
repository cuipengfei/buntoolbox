# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads)
for issue tracking. Use `bd` commands instead of markdown TODOs.
See AGENTS.md for workflow details.

## Project Overview

Buntoolbox 是一个全能开发环境 Docker 镜像，基于 Ubuntu，集成多种运行时和开发工具。

## 技术栈

- **基础镜像**: Ubuntu
- **JDK**: Azul Zulu (版本 11, 17, 21)
- **运行时**: Bun, Node.js, Python

## 构建命令

```bash
# 构建镜像
docker build -t buntoolbox .

# 运行容器
docker run -it buntoolbox
```

## 架构说明

单 Dockerfile 多阶段构建，按以下顺序安装组件：
1. Ubuntu 基础系统 + 常用工具
2. Azul Zulu JDK (多版本)
3. Node.js
4. Bun
5. Python
