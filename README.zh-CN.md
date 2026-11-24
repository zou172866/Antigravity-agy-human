<div align="center">

<img src="assets/logo.svg" alt="agy-clarity logo" width="80" />

# agy-clarity

**Google Antigravity 零依赖轻量插件：实时编程「通俗与技术精度平衡」表达规范 · 按需 `wait-what` 费曼拆解技能 · 兼容 Claude Code / Cursor / Codex**

简体中文 · [English](README.md) · [一键安装](#如何安装) · [效果对比](#三种表达风格对比) · [`wait-what` 拆解技能](#按需技能wait-what-深度复述) · [跨工具复用](#在-claude-code--cursor--codex-中复用)

</div>

---

## agy-clarity 是什么？

`agy-clarity` 是面向 **Google Antigravity 桌面端 / IDE** 的轻量纯文本插件（同时可直接复用到 **Claude Code**、**Cursor** 和 **Codex**）。

日常和 AI 写代码、排错时，回复经常走向两个极端：
1. **纯黑话堆砌**：满屏抽象名词和被动语态，看半天不知道到底改了什么、为什么会坏。
2. **过度大白话降智**：只给泛泛比喻，把文件路径、函数名、报错码、验证命令全吞掉，排错和 Code Review 根本没法落地。

`agy-clarity` 用两份精炼的纯 Markdown 规范把两边拉回甜点区：

- **常驻表达规范（[`rules/AGENTS.md`](rules/AGENTS.md)）**：插件开启即生效。小改动极简直出不拖节奏；复杂任务按倒金字塔输出——先用 1～2 句人话点破结论，紧接着逐字保留精确路径、函数/类名、配置键、原始报错与实跑验证结果，重点讲清根因与取舍。
- **按需 `wait-what` 拆解技能（[`skills/wait-what/SKILL.md`](skills/wait-what/SKILL.md)）**：当你没听懂上一轮技术解释、卡在复杂源码或报错里，说一句“说人话 / `wait-what` / 费曼拆解”即触发——按「一句话定位 → 人话拆解机制（含类比代码映射与失效边界）→ 技术锚点与易踩坑」三层讲透，不失真、不降智。

> **零外部运行时依赖**：不需要 Node.js，不需要 Python，不注册后台 Hook，也绝不修改 `~/.gemini/config/config.json`。

---

## 如何安装

在终端运行对应系统的一行命令，完成后 **重启或刷新 Antigravity 窗口** 即可生效。

**Windows（PowerShell 一行直装）：**

```powershell
irm https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.ps1 | iex
```

**macOS / Linux（一行直装）：**

```bash
curl -fsSL https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.sh | sh
```

**手动 `git clone` 安装：**

```powershell
# Windows (PowerShell)
git clone https://github.com/zou172866/Antigravity-agy-clarity.git "$HOME\.gemini\config\plugins\agy-clarity"
```

```bash
# macOS / Linux
git clone https://github.com/zou172866/Antigravity-agy-clarity.git "$HOME/.gemini/config/plugins/agy-clarity"
```

**仅安装 `wait-what` 技能（跨工具通用）：**

```bash
npx -y skills add zou172866/Antigravity-agy-clarity
```

**一键卸载：**

```powershell
# Windows（本地仓库目录运行）
.\install.ps1 -Uninstall

# Windows（远程一行卸载）
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.ps1))) -Uninstall
```

```bash
# macOS / Linux（本地仓库目录运行）
sh ./install.sh --uninstall

# macOS / Linux（远程一行卸载）
curl -fsSL https://raw.githubusercontent.com/zou172866/Antigravity-agy-clarity/main/install.sh | sh -s -- --uninstall
```

---

## 三种表达风格对比

假设刚刚修复了一个经典前端 Bug：用户在搜索框快速打字时，旧搜索结果偶尔会覆盖最新结果。看看同一次修复的三种回复差别：

### 1. 纯黑话堆砌（一眼看不懂重点）
> “通过在检索编排 Hook 中引入与组件生命周期绑定的请求取消语义，修复了并发异步状态变更场景下由乱序响应回填引发的非确定性状态回退异常。”

*问题*：每个字都认识，合在一起要读两遍才知道改了什么；而且没有给出具体文件、函数名和验证证据。

### 2. 过度大白话降智（看着热闹，没法排错/Review）
> “其实就是你发了两个外卖订单，先点那单送得慢，后送到就把你新点的餐给顶掉了！我帮你把旧订单直接取消了，现在应该没问题啦！”

*问题*：把工程锚点删光了——不知道改了哪个文件、有没有吞掉正常的 `AbortError`、跑没跑过测试，也看不出真实系统里服务端请求是否真被终止。

### 3. `agy-clarity` 平衡版（第一眼看懂 + 100% 保留技术精度）
> **结论**：搜索框快速输入时不会再闪回旧结果——每次新输入都会先取消上一次未完成的请求。
>
> - **根因**：前一次慢请求比新请求晚返回，把 `results` 状态覆盖成了旧数据（**异步竞态 / Race Condition**）。
> - **改法与取舍**：在 `src/hooks/useSearch.ts` 的 `useSearch` 中为每次 `useEffect` 创建 `AbortController`，清理阶段调用 `controller.abort()`，并在 `catch` 中忽略 `err.name === "AbortError"`。未仅采用递增 `requestId` 丢弃旧响应，是因为主动取消还能省去无用的网络传输与 JSON 解析。
> - **验证结果**：运行 `npm test -- useSearch.test.ts`，4/4 通过（含乱序返回模拟用例）。
> - **边界说明**：依赖运行环境的 `fetch` 支持 `AbortSignal`；已发到后端的查询仍会执行完，除非服务端监听连接断开。

*效果*：3 秒抓住意图，同时具备完整的排错与 Code Review 溯源信息。

---

## 常驻规范：`rules/AGENTS.md`

安装并启用 `agy-clarity` 后，`rules/AGENTS.md` 自动生效，覆盖五条核心原则：

1. **自适应详略**：1～2 处小修或明确查询直接极简回复（结论 + 改动位置/命令 + 验证结果），绝不啰嗦。
2. **倒金字塔（先人话结论，再给技术锚点）**：开头 1～2 句直白短句交代结果，紧跟逐字保留的文件路径、函数/类名、配置键、原始报错与真实命令输出。
3. **保留术语、就地翻译**：不在专业精度上降智；关键机制首次出现时先讲直白动作、再标专业术语；若用类比，必须立即映射回真实代码对象。
4. **讲 Why 和取舍，不复读 Diff**：Diff 已经展示了改了哪行，回复聚焦根因、方案取舍、隐含假设与已知边界。
5. **过程简报，收尾自包含**：多步任务在关键里程碑一句白话同步进度，不刷屏堆栈；收尾收敛为完整闭环（结论 → 根因与改法 → 验证结果 → 边界/下一步）。

---

## 按需技能：`wait-what` 深度复述

当你觉得上一轮解释太绕、看源码卡壳，或想彻底搞懂一段复杂机制时，在对话框直接触发：

- `用 wait-what 模式把刚才的报错根因和调用链用人话拆解一遍，并保留代码锚点`
- `没太听懂，用人话重讲一下这个状态机是怎么流转的，顺便说说最容易踩的坑`
- `用费曼拆解帮我理清 cache-analyzer.js 的命中判定逻辑`

### 三层阶梯输出结构

1. **一句话定位（上下文 + 结论）**：先补齐当前上下文，交代我们在解决什么问题、卡在哪个环节。
2. **人话拆解机制（直觉层）**：借鉴 ASD-STE100 简明技术句法（一句一件事、主动语态、主语明确）按因果/时间讲清数据与控制流。若使用类比，强制补全：
   - **代码映射**：类比中的 A = 代码里的 `xxx`，B = `yyy`。
   - **类比边界**：明确指出类比在什么地方失效（并发、持久化、重试、内存语义等）。
3. **技术锚点与易踩坑（精度层）**：列出精确文件路径与核心符号分支、说明设计权衡（Why & Trade-off），并点出 1～2 个最容易误解的边界或失败模式。

> **严格边界隔离**：`wait-what` 仅用于编程、排错与源码架构理解，**不会**误触发到自媒体或营销文案改写场景。

---

## 在 Claude Code / Cursor / Codex 中复用

`agy-clarity` 采用开放的 Markdown 规则与 Agent Skills 结构，可零成本复用到其他 AI 编程工具：

| 工具 | 常驻规范（`rules/AGENTS.md`） | 按需技能（`skills/wait-what`） |
| :--- | :--- | :--- |
| **Google Antigravity** | 一键安装脚本自动部署至 `~/.gemini/config/plugins/agy-clarity` | 随插件自动启用 |
| **Claude Code** | 将 `rules/AGENTS.md` 追加至 `~/.claude/CLAUDE.md` 或项目 `CLAUDE.md` | `npx -y skills add zou172866/Antigravity-agy-clarity` |
| **Cursor** | 复制 `rules/AGENTS.md` 为 `.cursor/rules/agy-clarity.mdc`（开启 `alwaysApply: true`） | `npx -y skills add zou172866/Antigravity-agy-clarity` |
| **OpenAI Codex** | 将 `rules/AGENTS.md` 追加至 `~/.codex/AGENTS.md` 或仓库 `AGENTS.md` | `npx -y skills add zou172866/Antigravity-agy-clarity` |

---

## 仓库目录结构

```text
Antigravity-agy-clarity/
├── plugin.json                 # Antigravity 官方插件清单
├── rules/
│   └── AGENTS.md               # 常驻「通俗与技术精度平衡」表达规范
├── skills/
│   └── wait-what/
│       └── SKILL.md            # 按需 wait-what / 费曼拆解技能
├── assets/
│   └── logo.svg                # 128×128 透明底明暗高对比矢量图标
├── install.ps1                 # Windows 零依赖 PowerShell 安装/卸载脚本
├── install.sh                  # macOS / Linux 零依赖 POSIX Shell 安装/卸载脚本（纯 LF）
├── README.md                   # 英文文档
├── README.zh-CN.md             # 简体中文文档
├── LICENSE                     # MIT 开源协议
├── .gitignore
└── .gitattributes              # 强制 *.sh 使用 LF、*.ps1 使用 CRLF
```

---

## 致谢与方法论来源

本项目的表达框架融合并借鉴了以下优秀社区项目与工程写作规范：

- [`smixs/awesome-claude-output-styles`](https://github.com/smixs/awesome-claude-output-styles) — 输出风格模式与信息密度平衡实践
- [`mattpocock/skills`](https://github.com/mattpocock/skills) — `wait-what` 按需复述与重构理解工作流
- [`anthropics/claude-plugins-official` (`explanatory-output-style`)](https://github.com/anthropics/claude-plugins-official) — 编程过程中同步解释设计要点与 Why 的输出模式
- [`guicortei/feynman-technique`](https://github.com/guicortei/feynman-technique) — 结构化费曼拆解与防自欺误区检验思路
- [`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman) — 去除空洞废话、保留高密度技术干货的精炼理念
- **ASD-STE100**（简明技术英语规范）— 一句一件事、主动语态、主语明确

---

## 开源协议

[MIT](LICENSE) © 2026 zou172866
