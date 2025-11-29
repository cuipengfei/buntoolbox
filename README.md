# Buntoolbox

> **Bun** + **Ubuntu** + **Toolbox** = 全能开发环境 Docker 镜像

## 包含组件

- **运行时**: Bun, Node.js 24, Python 3.12
- **JDK**: Azul Zulu 21 headless
- **基础镜像**: Ubuntu 24.04 LTS
- **常用工具**: git, gh, jq, ripgrep, fd, fzf, tmux, lazygit, helix, bat, eza 等

## 使用方式

```bash
docker pull yourname/buntoolbox:latest
docker run -it yourname/buntoolbox
```

## 命名由来

| 组合 | 含义 |
|------|------|
| Bun | 现代 JS 运行时 |
| (U)buntu | 稳定的 Linux 基底 |
| Toolbox | 多语言工具箱 |

---

*一个镜像，无限可能。*
