<div align="center">

[简体中文](README.zh-CN.md) · **English**

<img src="assets/logo.svg" alt="agy-human logo" width="80" />

# agy-human

**Google Antigravity plugin: speak human in live coding without losing technical precision · on-demand `wait-what` Feynman breakdown · zero Node/Python dependencies**

[How to Install](#how-to-install) · [Comparison](#before-vs-after-comparison) · [`wait-what` Skill](#on-demand-wait-what-skill) · [Cross-Tool Reuse](#use-with-claude-code-cursor--codex)

</div>

---

## What is agy-human?

`agy-human` is a lightweight, zero-dependency plugin for **Google Antigravity Desktop / IDE** (and directly reusable in **Claude Code**, **Cursor**, and **Codex**).

AI coding assistants often fall into one of two traps:
1. **Wall of jargon** — passive-voice essays packed with abstractions that hide what actually changed or broke.
2. **Dumbed-down hand-waving** — overly casual metaphors that omit file paths, symbols, error codes, and verification commands, leaving you with nothing usable for debugging or code review.

`agy-human` solves both with two pure-Markdown components:

- **Always-on Rule ([`rules/AGENTS.md`](rules/AGENTS.md))**: Keeps every coding turn immediately readable at a glance (inverted-pyramid headline first, mechanism before jargon, Why & trade-offs over diff narration) while preserving exact paths, symbols, parameters, error codes, and test outputs verbatim.
- **On-demand Skill ([`skills/wait-what/SKILL.md`](skills/wait-what/SKILL.md))**: Activates whenever you say *"深度复述"*, *"wait-what"*, *"explain in plain language"*, *"说人话"*, or *"费曼拆解"* during debugging or reading complex code — delivering a 3-tier breakdown with explicit analogy-to-code mappings and analogy failure boundaries.

> **Zero external runtime**: Pure Markdown + SVG + native shell installers. No Node.js, no Python, no background hooks, and never edits `~/.gemini/config/config.json`.
>
> **Language note**: The shipped prompt rules in `rules/AGENTS.md` and `skills/wait-what/SKILL.md` are crafted in Simplified Chinese (ideal for Chinese-speaking engineers working on multilingual/English codebases). You can translate or customize them freely after cloning.

---

## How to Install

Run the one-line installer for your OS, then **restart or reload your Antigravity window**.

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/zou172866/Antigravity-agy-human/main/install.ps1 | iex
```

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/zou172866/Antigravity-agy-human/main/install.sh | sh
```

**Manual `git clone` install:**

```bash
# macOS / Linux
git clone https://github.com/zou172866/Antigravity-agy-human.git "$HOME/.gemini/config/plugins/agy-human"
```

```powershell
# Windows (PowerShell)
git clone https://github.com/zou172866/Antigravity-agy-human.git "$HOME\.gemini\config\plugins\agy-human"
```

**Skill-only install (cross-agent via `npx skills`):**

```bash
npx -y skills add zou172866/Antigravity-agy-human
```

**Uninstall:**

```powershell
# Windows (local clone)
.\install.ps1 -Uninstall

# Windows (remote one-liner)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/zou172866/Antigravity-agy-human/main/install.ps1))) -Uninstall
```

```bash
# macOS / Linux (local clone)
sh ./install.sh --uninstall

# macOS / Linux (remote one-liner)
curl -fsSL https://raw.githubusercontent.com/zou172866/Antigravity-agy-human/main/install.sh | sh -s -- --uninstall
```

---

## Before vs. After Comparison

Suppose you just fixed a classic search-box bug where typing fast causes stale results to overwrite newer ones. Compare three ways an AI assistant explains the exact same fix:

### 1. Jargon Wall (Dense, buries the point)
> "A nondeterministic asynchronous state mutation anomaly was remediated via lifecycle-bound cancellation semantics within the search orchestration hook, eliminating out-of-order response reconciliation regressions across concurrent invocations."

*Problem*: Sounds smart, forces you to re-read twice just to learn what broke, and still hides the exact file, symbol, and verification result.

### 2. Over-simplified / Dumbed-Down (Friendly, useless for engineering)
> "Basically your two searches were racing each other like two delivery drivers, and the slower driver arrived last and swapped your food! I fixed it so the old delivery gets canceled. Everything looks good now!"

*Problem*: Cute analogy, zero engineering traceability. No file path, no symbol name, no error handling detail, no proof anything was tested, and the analogy hides real edge cases like `AbortError` handling.

### 3. `agy-human` Balanced (Plain headline + exact technical anchors)
> **Conclusion**: Typing quickly in the search box no longer flashes stale results — each new keystroke now cancels the previous in-flight request before issuing the next one.
>
> - **Root cause**: An earlier slower request returned after a newer request and overwrote `results` state (**asynchronous race condition**).
> - **Change & Why**: Added an `AbortController` per effect cycle in `src/hooks/useSearch.ts` (`useSearch`, `useEffect` cleanup calls `controller.abort()`), and ignored `err.name === "AbortError"` in `catch`. Chose request cancellation over a monotonically increasing `requestId` guard alone because it also saves redundant network/JSON parsing work.
> - **Verification**: `npm test -- useSearch.test.ts` → 4/4 passed (including out-of-order mock response resolution).
> - **Boundary / Caveat**: Assumes the underlying `fetch` polyfill honors `AbortSignal`; server-side queries already started still run to completion unless the API checks client disconnect.

*Result*: You grasp the change in 3 seconds **and** have every exact anchor needed for code review and future debugging.

---

## Always-On Rule: `rules/AGENTS.md`

While `agy-human` is enabled in Antigravity, `rules/AGENTS.md` is automatically loaded with five disciplined principles:

1. **Adaptive Verbosity**: Tiny 1–2 file fixes or direct lookups get a terse one-line answer (`conclusion + location/command + verification`). Complex tasks use the layered structure.
2. **Inverted Pyramid (Plain Conclusion → Technical Anchors)**: Lead with 1–2 short, active-voice sentences stating what changed or broke; immediately follow with verbatim file paths, function/class names, config keys, error codes, and actual test results.
3. **Mechanism Before Name & Grounded Analogies**: Keep real engineering terminology — explain what happens first in plain action words, then attach the accurate term. Any analogy must immediately map back to real code objects.
4. **Why & Trade-offs Over Diff Narration**: The diff already shows *what* lines changed; explain the root cause, why this design beat alternatives, implicit assumptions, and known boundaries.
5. **Milestone Briefs & Self-Contained Closing**: During multi-step work, give crisp plain-language progress checkpoints without dumping raw stack traces; end with a clean closed loop (`Conclusion → Root Cause & Fix → Verification → Caveats / Next Step`).

---

## On-Demand `wait-what` Skill

When an explanation still feels foggy — or you are stepping through unfamiliar architecture or a tangled stack trace — invoke `wait-what` naturally in chat:

- *"深度复述 / wait-what — explain that race condition again in plain words without dropping code anchors"*
- *"用人话把刚才那段状态流转重讲一遍，顺便说说最容易误解的点"*
- *"用费曼拆解帮我看懂 `store.js` 和 `cache-analyzer.js` 怎么协作"*

### How `wait-what` responds (3-Tier Ladder)

1. **One-Line Orientation (Context + Conclusion)**: Re-establishes what problem we are solving and where we are stuck (never assumes you held all prior context).
2. **Plain Mechanism Breakdown (Intuition Layer)**: Walks causal/chronological data and control flow in short, active-voice sentences (inspired by ASD-STE100). If an analogy helps, it strictly prints:
   - **Code Mapping**: Analogy A = `actualSymbolA`, B = `actualSymbolB`.
   - **Analogy Boundary**: Where the real system diverges (concurrency, persistence, retries, memory semantics).
3. **Technical Anchors & Pitfalls (Precision Layer)**: Exact file paths/symbols/branches, *Why & Trade-off*, and 1–2 common misconceptions or failure modes.

> **Scope guard**: `wait-what` is strictly scoped to programming, debugging, and source-code comprehension — it will **not** hijack marketing or social-media copywriting requests.

---

## Use with Claude Code, Cursor & Codex

Because `agy-human` is pure Markdown following open agent standards, you can reuse both parts across other coding agents:

| Tool | Always-On Rule (`rules/AGENTS.md`) | On-Demand Skill (`skills/wait-what`) |
| :--- | :--- | :--- |
| **Google Antigravity** | Automatic via one-line installer (`~/.gemini/config/plugins/agy-human`) | Automatic via plugin |
| **Claude Code** | Append `rules/AGENTS.md` into `~/.claude/CLAUDE.md` or project `CLAUDE.md` | `npx -y skills add zou172866/Antigravity-agy-human` |
| **Cursor** | Copy `rules/AGENTS.md` into `.cursor/rules/agy-human.mdc` (`alwaysApply: true`) | `npx -y skills add zou172866/Antigravity-agy-human` |
| **OpenAI Codex** | Append `rules/AGENTS.md` into `~/.codex/AGENTS.md` or repo `AGENTS.md` | `npx -y skills add zou172866/Antigravity-agy-human` |

---

## Repository Structure

```text
Antigravity-agy-human/
├── plugin.json                 # Official Antigravity plugin manifest
├── rules/
│   └── AGENTS.md               # Always-on balanced coding communication rule
├── skills/
│   └── wait-what/
│       └── SKILL.md            # On-demand wait-what / Feynman breakdown skill
├── assets/
│   └── logo.svg                # 128x128 transparent high-contrast vector icon
├── install.ps1                 # Zero-dependency Windows PowerShell installer/uninstaller
├── install.sh                  # Zero-dependency POSIX sh installer/uninstaller (LF)
├── README.md                   # English documentation
├── README.zh-CN.md             # Simplified Chinese documentation
├── LICENSE                     # MIT License
├── .gitignore
└── .gitattributes              # Enforces LF for *.sh and CRLF for *.ps1
```

---

## Credits & Inspiration

`agy-human` synthesizes practical ideas from open-source prompt engineering and technical writing communities:

- [`smixs/awesome-claude-output-styles`](https://github.com/smixs/awesome-claude-output-styles) — curated output style patterns balancing clarity and signal density
- [`mattpocock/skills`](https://github.com/mattpocock/skills) — the `wait-what` restatement workflow for re-explaining dense code concepts on demand
- [`anthropics/claude-plugins-official` (`explanatory-output-style`)](https://github.com/anthropics/claude-plugins-official) — surfacing concise design insights and *Why* alongside code edits
- [`guicortei/feynman-technique`](https://github.com/guicortei/feynman-technique) — structured Feynman breakdown and misconception checks
- [`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman) — stripping filler prose while keeping high-density technical substance
- **ASD-STE100** (Simplified Technical English) — one idea per sentence, active voice, and unambiguous actors

---

## License

[MIT](LICENSE) © 2026 zou172866
