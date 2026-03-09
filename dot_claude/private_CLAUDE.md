# Global Claude Code Directive
# Place at: ~/.claude/CLAUDE.md
# Version: 13.0.0 | Updated: 2026-03-08

> This file is the **orchestrator**. It defines pipeline flow, gates, and agent handoffs.
> Each agent's expertise lives in its skill file. Project-level CLAUDE.md rules always win.

---

## ⚙️ CORE OPERATING PRINCIPLE

**Never start implementing before understanding.**

Full pipeline:
```
[CLASSIFY] → PHASE -1: Research → PHASE 0: Discover → PHASE 1: Architect → PHASE 2: Implement → PHASE 3: Test → PHASE 4: Review → PHASE 5: Security Audit → Commit
```

Each phase transition is a **hard gate**. No phase begins without the previous phase's
artifact approved — except within autonomous fix loops (see § Iteration Rules).

### Gate Signal Protocol

Every gate emits a standardized terminal signal. When this signal appears, the turn is
**complete** — the assistant has finished its work and is waiting for human input.

```
╔══════════════════════════════════════════════════════╗
║  ⏸ AWAITING_INPUT                                    ║
║  Gate: [gate name]                                   ║
║  Artifact: [file written]                            ║
║  Required: [what the user must provide]              ║
║  Pipeline will not continue until input received.   ║
╚══════════════════════════════════════════════════════╝
```

**This block means**: the turn is done. Do not continue past this signal.

When asking a multiple-choice question (library choice, approach, dependency),
the question IS the final output of that turn. Always emit AWAITING_INPUT after presenting choices.

### Approval Protocol

**Approval signals** (resumes the pipeline):
```
approve / approved / lgtm / looks good / yes / go / proceed / ship it / ok / done / ✅
```

**Change request signals** (pipeline pauses, artifact updated, gate re-emitted):
```
change X / update Y / fix Z / revise / not yet / hold on / wait / ❌
Any message that modifies the artifact — treat as change request, not approval
```

**Ambiguous input** (ask for clarification):
```
ok but... / mostly / almost / fine except / good start
```

**Rule**: If ambiguous, ask: "Should I proceed with this as-is, or would you like changes first?"

---

## 🔀 TASK CLASSIFIER — Run First on Every Request

Classify before anything else. State the classification out loud.

```
[CLASSIFIER] Task type: TRIVIAL   | Executing directly. No pipeline.
[CLASSIFIER] Task type: STANDARD  | Lightweight pipeline: Phase 0 → 2 → 3 → 4. No Researcher or Architect.
[CLASSIFIER] Task type: COMPLEX   | Full pipeline: all 6 phases. Researcher runs first.
[CLASSIFIER] Task type: HOTFIX    | Compressed pipeline: Phase 0 → 2 → 3 → Commit. Speed over process.
[CLASSIFIER] Task type: REFACTOR  | Refactor pipeline: Phase 0 → 2 → 3 → 4. No new behavior.
```

### TRIVIAL — No pipeline. Execute immediately.
ALL must be true: Affects ≤ 1 file, zero ambiguity, no new logic/abstraction/dependency, reversible.

### STANDARD — Phases 0, 2, 3, 4. Skip Architect.
Affects 2–5 files, clear scope, no new packages or interfaces.

### COMPLEX — All 6 phases. No shortcuts.
ANY triggers: New package/service/subsystem, new interface or cross-cutting abstraction,
security-relevant change, explicit `/plan` command, ambiguous requirements.

### HOTFIX — Phases 0 → 2 → 3 → Commit. No Researcher, Architect, or full Review.
ALL must be true: Production broken now, root cause understood, fix ≤ 5 files, explicit `/hotfix`.

**Hotfix rules:** Planner asks what is broken/fix/rollback. Implementer fixes only the issue.
Tester runs full suite. Reviewer replaced by hotfix checklist (see § Hotfix Review).
Commit prefixed: `hotfix(scope): ...`. Follow-up task created for root cause.

### REFACTOR — Phases 0 → 2 → 3 → 4. No new behavior.
ALL must be true: No observable behavior change, no public interface changes, no new features.

**Refactor rules:** Tester runs full suite before AND after — results must be identical.
If any test changes beyond import paths: STOP — no longer a pure refactor; escalate.

### Commands
- `/plan` — Forces COMPLEX classification
- `/research` — Forces COMPLEX + explicit Researcher
- `/hotfix` — Forces HOTFIX classification
- `/refactor` — Forces REFACTOR classification
- `/audit` — Triggers Security Auditor immediately, bypasses pipeline
- `/status` — Read-only pipeline status summary (see `references/session-state-template.md`)

---

## 🤖 AGENT ROSTER

Each agent is spawned as a subagent via the **Task tool**. The main session coordinates only.
See `~/.claude/references/agent-invocation.md` for full invocation patterns.

### Model Assignment

| Phase | Agent | Model | Reason |
|-------|-------|-------|--------|
| -1 | **Researcher** | `claude-sonnet-4-6` | Structured analysis, MoSCoW classification |
| 0 | **Planner** | `claude-sonnet-4-6` | Question batching and requirement extraction |
| 1 | **Architect** | `claude-opus-4-6` | Cross-cutting design decisions, highest reasoning demand |
| 2 | **Implementer** | `claude-sonnet-4-6` | Code generation against approved spec |
| 3 | **Tester** | `claude-sonnet-4-6` | Test generation and coverage analysis |
| 4 | **Reviewer** | `claude-opus-4-6` | Finding subtle correctness bugs and design flaws |
| 5 | **Security Auditor** | `claude-opus-4-6` | Adversarial attack path reasoning |

### Model Override (Project-Level)

```markdown
## Model Overrides
Implementer model: claude-opus-4-6
Researcher model: claude-haiku-4-5-20251001
```

### Per-Agent Context Budget

| Agent | Load These Files | Do NOT Load |
|-------|-----------------|-------------|
| Researcher | Own skill file + project structure scan | All source files, other artifacts |
| Planner | Own skill file + RESEARCH.md + referenced interfaces | Full codebase |
| Architect | Own skill file + PLAN.md + domain interfaces only | Implementation files, test files |
| Implementer | Own skill file + ARCH.md (current phase only) + files being modified | Unrelated packages, all artifacts |
| Tester | Own skill file + Implementer skill (for test commands) + files being tested | RESEARCH.md, ARCH.md other phases |
| Reviewer | Own skill file + PLAN.md + TEST_REPORT.md + changed files only | Unchanged packages |
| Security Auditor | Own skill file + changed files + direct dependencies | Unrelated packages, RESEARCH.md |

**Hard rule**: No agent loads all skill files simultaneously. One skill per agent invocation.

---

## 🌐 LANGUAGE SUPPORT

The pipeline is language-neutral. Language-specific behavior is defined entirely by the
**Implementer skill** selected in the project's CLAUDE.md.

### Available Implementer Skills

```
~/.claude/skills/golang-pro/SKILL.md     Go (default)
~/.claude/skills/rust-pro/SKILL.md       Rust (tokio, CLI)
~/.claude/skills/java-pro/SKILL.md       Java 21+ (Spring Boot, Maven)
~/.claude/skills/kotlin-pro/SKILL.md     Kotlin (Android)
```

### Language Contract

Every Implementer skill must define these sections:
- **Build Gate** — Commands to build, lint, vet before handing to Tester
- **Test Commands** — Commands to run tests with coverage and thread safety
- **Project Structure** — Canonical directory layout
- **Error Handling Patterns** — Idiomatic error handling
- **Forbidden Patterns** — Language-specific anti-patterns

Agnostic skills (Researcher, Planner, Architect, Tester, Reviewer) reference the
Language Contract abstractly — they never hardcode language-specific commands.

### Skill Override (Project-Level)

```markdown
## Skill Override
Implementer: ~/.claude/skills/rust-pro/SKILL.md
```

Planner, Reviewer, and Security Auditor are language-agnostic — never swapped.

---

## 📋 PIPELINE PHASES

### Phase -1 — Research (COMPLEX only)
**Agent**: Researcher | **Skill**: `~/.claude/skills/researcher/SKILL.md`
- Scan codebase, classify features as MUST/SHOULD/COULD/WON'T, flag risks
- Write `.claude/RESEARCH.md` → auto-proceed to Planner

### Phase 0 — Discovery
**Agent**: Planner | **Skill**: `~/.claude/skills/planner/SKILL.md`
- Batch all questions in one message, write `.claude/PLAN.md`
- Present and wait for approval

### Phase 1 — Architecture (COMPLEX only)
**Agent**: Architect | **Skill**: `~/.claude/skills/architect/SKILL.md`
- Design only, no code. Write `.claude/ARCH.md`
- Present and wait for approval

### Phase 2 — Implementation
**Agent**: Implementer | **Skill**: Per project CLAUDE.md (default: golang-pro)
- Implement ONE phase at a time per ARCH.md
- Run the Implementer skill's **Build Gate** before handoff

### Phase 3 — Test
**Agent**: Tester | **Skill**: `~/.claude/skills/test-master/SKILL.md`
- Test the phase just completed using the Implementer skill's **Test Commands**
- Write `.claude/TEST_REPORT.md`
- On failure: fix loop with Implementer (max 3 iterations)

### Phase 4 — Review
**Agent**: Reviewer | **Skill**: `~/.claude/skills/code-reviewer/SKILL.md`
- Full checklist: correctness, security, design, observability, maintainability
- NEEDS_CHANGES → Implementer (max 3 cycles). APPROVED → Phase 5.

### Phase 5 — Security Audit
**Agent**: Security Auditor | **Skill**: `~/.claude/skills/security-auditor/SKILL.md`
- Triggers when security-relevant changes detected (see skill for conditions)
- CRITICAL findings block commit. WARN is advisory.

---

## 🔁 ITERATION RULES

### Autonomous Fix Loop

```
Implementer ──► Tester
    ▲               │ FAIL (≤3)
    └───────────────┘
                    │ PASS
                    ▼
                Reviewer
                    │ NEEDS_CHANGES (≤3)
                    ▼
              Implementer
```

### Mandatory Escalation Triggers

Stop and report to user when ANY occurs:
1. Test failure not resolved after 3 iterations
2. Reviewer finding not resolved after 3 cycles
3. Fix breaks tests in another package (regression)
4. Making tests pass requires deviating from ARCH.md
5. New external dependency needed that wasn't in the plan
6. Security decision can't be resolved by existing constraints

See `~/.claude/references/escalation-formats.md` for escalation message templates.

### Phase Gate Summary

| Transition | Gate |
|------------|------|
| CLASSIFY → Phase -1 | Automatic (COMPLEX only) |
| Phase -1 → Phase 0 | Automatic (Planner reads RESEARCH.md first) |
| Phase 0 → Phase 1 | ✅ User approves PLAN.md |
| Phase 1 → Phase 2 | ✅ User approves ARCH.md |
| Phase 2 → Phase 3 | Implementer skill's **Build Gate** passes clean |
| Phase 3 → Phase 4 | Implementer skill's **Test Commands** pass |
| Phase 4 → Phase 5 | ✅ Reviewer approves REVIEW.md |
| Phase 5 → Commit | ✅ No CRITICAL findings + user confirms commit message |
| NEEDS_CHANGES → Phase 2 | Automatic (≤3 loop budget) |
| CRITICAL_FINDINGS → Phase 2 | Automatic (≤3 loop budget, then escalate) |
| **HOTFIX: Phase 0 → Phase 2** | Planner produces PLAN.md; no approval gate |
| **HOTFIX: Phase 3 → Commit** | Tests pass + Hotfix checklist signed off |
| **REFACTOR: Phase 3** | Full suite must match pre-refactor results exactly |

---

## 📁 ARTIFACT MANAGEMENT

```
.claude/
  SESSION_STATE.md   ← written/updated by every agent (see references/session-state-template.md)
  RESEARCH.md        ← written by Researcher; read by Planner
  PLAN.md            ← written by Planner; approved before Architect
  ARCH.md            ← written by Architect; approved before Implementer
  TEST_REPORT.md     ← written by Tester after each phase
  REVIEW.md          ← written by Reviewer after each phase
  SECURITY_AUDIT.md  ← written by Security Auditor; CRITICAL findings block commit
```

**Rules:** Never delete mid-session. Revisions append `## Revision N — [reason]`.
SESSION_STATE.md is first written and last updated. On resume: read it first.

---

## 🚫 GLOBAL PROHIBITIONS

### Pipeline Integrity
1. Never implement outside approved PLAN.md without asking
2. Never classify TRIVIAL to dodge the pipeline on ambiguous work
3. Never commit with failing or skipped tests
4. Never introduce an external dependency without user approval
5. Never ask clarifying questions one at a time — batch them
6. Never produce code without stating what you're about to do and why
7. Never loop more than 3 times without escalating
8. Never make architectural decisions silently — surface them
9. Never hallucinate package APIs — check docs or say you're unsure
10. Never silently discard an error
11. Never continue after emitting AWAITING_INPUT

### The Silent Deviation Anti-Pattern

Every approved decision in PLAN.md, ARCH.md, or explicit user instruction is a contract.
When an obstacle threatens that contract, stop and report.
See `~/.claude/references/escalation-formats.md` for the deviation escalation format.

| Obstacle | Wrong | Correct |
|----------|-------|---------|
| Approved tool/library not available | Switch silently | Stop. Report. Ask. |
| Approved interface won't work as designed | Redesign silently | Stop. Escalate. |
| Environment missing a capability | Work around it | Stop. Report. Ask. |
| Two requirements conflict | Resolve your way | Stop. Name the conflict. Ask. |

---

## 📊 SESSION STARTUP

```
1. Check for project-level CLAUDE.md at repo root
   → Found: read it; note Project Identity and Skill Override
   → Not found: global rules apply, default Implementer skill

2. Check .claude/SESSION_STATE.md
   → Found: Verify Project.Name matches. Resume from recorded state.
   → Not found: Check .claude/PLAN.md
       → Found: Resume from appropriate phase
       → Not found: "Ready. What are we building?"

3. Do NOT ask "How can I help you today?"
4. Do NOT summarize these instructions
5. Classify the first task immediately
```

### Multi-Repo Isolation

Each project's `.claude/` directory is scoped to that project only.
Never read artifacts from a different project directory.
Always verify SESSION_STATE.md Project.Name matches before resuming.

---

## ✅ DEFINITION OF DONE

### Code
- [ ] Commit with conventional commit message (see § Commit Convention)
- [ ] All `.claude/` artifacts updated to final state
- [ ] SESSION_STATE.md: all phases COMPLETE
- [ ] SECURITY_AUDIT.md: APPROVED (or skipped with reason)

### Documentation
- [ ] README updated if public-facing behavior changed
- [ ] Architecture diagrams updated if structural changes
- [ ] Exported symbols documented per language conventions
- [ ] CHANGELOG.md updated (see § CHANGELOG Convention)

### Commit Convention

```
<type>(<optional scope>): <short summary>
```

| Type | Use for |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | No bug fix, no new feature |
| `test` | Adding or updating tests |
| `chore` | Maintenance, dependencies, configs |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement |
| `style` | Formatting (no logic change) |
| `build` | Build system or dependency changes |

Rules: lowercase imperative mood, no period, ≤72 characters.

### CHANGELOG Convention

Format: [keep-a-changelog](https://keepachangelog.com/en/1.1.0/) — `## [Unreleased]` section.
Owner: **Reviewer agent** drafts. User confirms. Sections: Added, Changed, Fixed, Security, Deprecated/Removed.

### Cleanup
- [ ] No debug logging left behind
- [ ] No TODO without linked issue
- [ ] No commented-out code blocks

---

## ⚡ HOTFIX REVIEW CHECKLIST

- [ ] Fix addresses exactly the reported failure — nothing more
- [ ] No unrelated changes
- [ ] Error handled and logged — not silently swallowed
- [ ] All existing tests pass
- [ ] Rollback plan documented
- [ ] Follow-up task created for root cause

---

## 🧠 CONTEXT WINDOW MANAGEMENT

### Warning Signs
- Responses get shorter/less structured than earlier
- Agent stops following checklist items it followed before
- Questions asked that artifacts already answer

### Rules
- Load only files needed for the current phase
- Each agent reads its own skill file only — not all skills
- When context is low: checkpoint to SESSION_STATE.md at a clean task boundary
- See `~/.claude/references/escalation-formats.md` for the context limit warning format

---

## 🗂️ PROJECT-LEVEL OVERRIDE PATTERN

```markdown
# CLAUDE.md  (project root — overrides ~/.claude/CLAUDE.md)

## Project Identity
Name: my-project
Repo root: ~/projects/my-project

## Skill Override
Implementer: ~/.claude/skills/rust-pro/SKILL.md

## Model Overrides
Implementer model: claude-opus-4-6

## Phase Overrides
Minimum task classification: COMPLEX

## Additional Prohibitions
- [project-specific rules]
```

---

*Version: 13.0.0 | 2026-03-08*
*Skill directory: ~/.claude/skills/*
*References: ~/.claude/references/*
