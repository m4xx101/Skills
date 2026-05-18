---
name: universal-pre-compact-prep
description: Writes four durable artifact bundles before any agent harness compacts or resets context, so the next session starts from a paste-and-go resume prompt instead of a blank slate.
tags: [agent-skill, context-management, cross-harness, memory, compaction]
version: 1.0.0
author: m4xx101
license: MIT
date: 2026-05-15
---

# Universal Pre-Compact Prep

Context compaction discards the live conversation and replaces it with an auto-generated
summary. Decisions, in-progress plans, gate states, and deferred todos get reduced to
bullet points or dropped entirely. This skill writes them down into durable surfaces before
the compaction fires, so the next session reads structured artifacts instead of
reconstructing from summary.

## When to invoke

Trigger ONLY on these explicit phrases:
- `/compact-prep`, `/pre-compact`, "compact this session", "pre-compact prep", "before compact"
- Harness equivalents: `/summarize-session` (Codex), `/freeze-state` (Hermes custom), `/session-save` (OpenCode custom)

Do NOT trigger on: "running low on context", "wrap up", "freeze state", generic compaction
mentions. If compaction intent is signalled without a listed phrase, ask once; do not auto-invoke.

## Harness detection

Run at skill start. Resolves all path variables used in the bundles.

```bash
detect_harness() {
  if   [ -d "$HOME/.claude" ];            then echo "claude-code"
  elif [ -d "$HOME/.hermes" ];            then echo "hermes"
  elif [ -d "$HOME/.config/opencode" ];   then echo "opencode"
  elif command -v codex >/dev/null 2>&1;  then echo "codex"
  else echo "generic"; fi
}
HARNESS=$(detect_harness)
```

| Harness | Memory root | Plans root |
|---|---|---|
| claude-code | `~/.claude/projects/<encoded-cwd>/memory/` | `~/.claude/plans/` |
| hermes | `~/.hermes/wiki/` | `~/.hermes/plans/` |
| opencode | `~/.config/opencode/memory/` | `~/.config/opencode/plans/` |
| codex | `.codex-memory/` (cwd-local) | n/a |
| generic | `.agent-memory/` (cwd-local) | n/a |

For `claude-code`, find the encoded project dir: `ls ~/.claude/projects/ | grep -i "$(basename "$(pwd)")"`.
Create it if absent.

---

## Bundle 1 - Memory files + index

Write one file per substantive deliverable to the harness memory root, named `<topic-slug>.md`:

```markdown
---
name: <name + date>
description: <one-line relevance hook>
type: project | feature | decision | reference
---
WHAT decisions were made and what is open.
WHY each decision was made.
HOW to apply: commands, file paths, commit SHAs.
WHEN this expires if time-bounded.
```

Update (or create) `MEMORY.md` in the same dir as the index:
`- [Topic name](topic-slug.md) - <one-line hook>`
Keep the index under 150 lines. Order by recency.

**Skip:** No substantive deliverables. Log: `[skip] memory - no durable artifacts`.

---

## Bundle 2 - Handoff doc

**Where:** `<repo-root>/docs/<YYYY-MM-DD>-handoff-<topic>.md`. Create `docs/` if absent.

Required sections: state table (last commit SHA, origin sync status, worktree branch + dirty
flag, test status), bulleted "done" list with commit SHAs, numbered "deferred" list (track
name + files + verification gate + sequence), start commands, hard constraints, diagnostic
commands.

Capture git state and embed it:

```bash
git log --oneline -10
git status --short | head -20
git diff --stat origin/$(git branch --show-current)..HEAD 2>/dev/null | tail -5
```

**Skip:** No `.git` and no `docs/`. Log: `[skip] handoff - not in a trackable repo`.

---

## Bundle 3 - Plan delta + graph refresh

### Plan-file delta

Locate the active plan (most-recently-modified `.md` referencing this session's work):

```bash
ls -t ~/.claude/plans/*.md              2>/dev/null | head -3   # claude-code
ls -t ~/.hermes/plans/*.md              2>/dev/null | head -3   # hermes
ls -t ~/.config/opencode/plans/*.md     2>/dev/null | head -3   # opencode
ls -t docs/superpowers/plans/*.md       2>/dev/null | head -3   # superpowers convention
```

Append to the bottom of the matched file:

```markdown
---
## Last session ended at <YYYY-MM-DD HH:MM>
**HEAD:** <sha> - <subject>
**Status:** <done phase / next phase>
**New decisions:** <bullets>
```

**Skip:** No matching plan file. Log: `[skip] plan delta - no active plan`.

### Graphify refresh

```bash
[ -d graphify-out ] && graphify update . 2>&1 | tail -5
```

AST-only, no API cost. Refreshes `graphify-out/GRAPH_REPORT.md` to code state at compact time.
If `graphify` not on PATH: `[skip] graphify - not on PATH (pip install graphifyy)`.

**Skip:** No `graphify-out/`. Log: `[skip] graphify - no graphify-out/ found`.

---

## Bundle 4 - Resume prompt

Print as a fenced code block in chat. Do NOT write to a file. User pastes this as their first
message after compaction.

```
Continue <topic> work after compact. Read in this order before any tool calls:
1. <repo-root>/docs/<YYYY-MM-DD>-handoff-<topic>.md
2. <plan-path, or "no active plan file">
3. <memory-root>/<key-memory-slug>.md
4. <repo-root>/CLAUDE.md (or equivalent conventions file)

Verify: HEAD at `<sha>` or later. Run `git pull origin <branch>`. <health-check> must pass.
First track: <track>. <one sentence rationale from handoff doc>.
Rules: <constraint 1> / <constraint 2> / <constraint 3>.
On ambiguity the plan does not resolve: ask, do not guess.
```

Adapt: chain work - add engine version + mode. UI work - add dev-server URL. Deploy-sensitive -
repeat the hard-locked deploy contract. If `graphify-out/` exists - add "read
graphify-out/GRAPH_REPORT.md first". Codex/generic - omit memory-root line.

**Skip:** Never. Minimum output: "at `<sha>`, nothing in flight".

---

## Order of operations

1. Memory (handoff cites stable paths).
2. Handoff (cites memory + plan paths).
3. Plan delta + graphify.
4. Resume prompt (cites all upstream).

On bundle failure: log inline and continue. Partial preservation beats abort.

## Final summary message

```
Pre-compact prep complete. Wrote / updated:
- Memory:   <paths or "skip - <reason>">
- Handoff:  <docs/<file>.md or "skip - <reason>">
- Plan:     <path or "skip - <reason>">
- Graphify: <"refreshed N nodes" or "skip - <reason>">

Resume prompt for next session:
<resume-prompt block>

Safe to compact now.
```

## Working rules

- No clarifying questions. Defaults: topic = most-discussed thread, date = today,
  filename = `<date>-handoff-<topic>.md`.
- One chat line per bundle ("writing X to Y"). No commentary.
- Log skips only in the final summary, not inline.
- Never delete files. Conflict with existing memory file: append `-2.md`.
- Always output the resume prompt.

## Adapter notes

- **Claude Code:** Memory `~/.claude/projects/<encoded-cwd>/memory/`. Plans `~/.claude/plans/`.
  Encoding: replace `/`, `\`, `:` with `-`. Detect: `~/.claude` exists.
- **Hermes Agent:** Memory `~/.hermes/wiki/`. Plans `~/.hermes/plans/`. Detect: `~/.hermes` exists.
- **OpenCode:** Memory `~/.config/opencode/memory/`. Plans `~/.config/opencode/plans/`.
  Detect: `~/.config/opencode` exists.
- **Codex CLI:** Memory `.codex-memory/` (cwd-local). No plans path; skip plan delta.
  Detect: `codex` on PATH.
- **Generic:** Memory `.agent-memory/` (repo root). Plan delta skipped. Detect: none of the above.
- **Cross-platform:** Forward slashes in markdown content; native separators in shell commands.
  `~/.claude/projects/` on Windows via Git Bash resolves as `C:/Users/<user>/.claude/projects/`.
