# Global Claude Code Directive
# Place at: ~/.claude/CLAUDE.md
# Version: 12.0.0 | Updated: 2026-03-08

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
**complete** — the assistant has finished its work and is waiting for human input. Any
external evaluator, hook, or continuation system must treat this signal as a stop condition,
not as incomplete work.

```
╔══════════════════════════════════════════════════════╗
║  ⏸ AWAITING_INPUT                                    ║
║  Gate: [gate name]                                   ║
║  Artifact: [file written]                            ║
║  Required: [what the user must provide]              ║
║  Pipeline will not continue until input received.   ║
╚══════════════════════════════════════════════════════╝
```

**This block means**: the turn is done. The assistant has produced its output and is
waiting for a human decision. This is NOT an incomplete task — it is a completed turn
at a designed checkpoint. Autonomous continuation past this signal is a pipeline violation.

When asking the user a multiple-choice question (library choice, approach, dependency),
the question IS the final output of that turn. Answering it autonomously defeats the
purpose of the question. Always emit the AWAITING_INPUT block after presenting choices.

### Approval Protocol

Defines what constitutes a valid response at each gate. Ambiguous input must be clarified
before the pipeline continues — do not assume intent.

**Approval signals** (any of these resumes the pipeline):
```
approve / approved / lgtm / looks good / yes / go / proceed / ship it / ok / done / ✅
```

**Change request signals** (pipeline pauses, artifact updated, gate re-emitted):
```
change X / update Y / fix Z / revise / not yet / hold on / wait / ❌
Any message that modifies the artifact — treat as change request, not approval
```

**Ambiguous input** (ask for clarification before acting):
```
ok but... / mostly / almost / fine except / good start
```

**Rule**: If the user's response could mean either approval or change request, ask:
`"Should I proceed with this as-is, or would you like changes first?"`
Never interpret ambiguous input as approval.

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
ALL must be true:
- Affects ≤ 1 file
- Zero ambiguity
- No new logic, abstraction, or dependency
- Reversible with a single undo

### STANDARD — Phases 0, 2, 3, 4. Skip Architect.
- Affects 2–5 files
- Clear scope, no new packages or interfaces

### COMPLEX — All 6 phases. No shortcuts.
ANY triggers this:
- New package, service, or subsystem
- New interface or cross-cutting abstraction
- Security-relevant change
- Explicit `/plan` command
- Ambiguous requirements

### HOTFIX — Compressed pipeline. Phases 0 → 2 → 3 → Commit. No Researcher, Architect, or full Review.
ALL must be true:
- Production is broken or degraded right now
- Root cause is understood
- Fix is contained (≤ 5 files, no new abstractions)
- Explicit `/hotfix` command used

**Hotfix rules:**
- Planner asks only: what is broken, what is the fix, what is the rollback plan
- Implementer fixes only the identified issue — no opportunistic cleanup
- Tester runs full suite — tests must still pass; do not skip `-race`
- Reviewer is replaced by a fast checklist (see § Hotfix Review)
- Commit message prefixed: `hotfix(scope): ...`
- A follow-up STANDARD or COMPLEX task must be created to address root cause properly

### REFACTOR — Phases 0 → 2 → 3 → 4. No Researcher or Architect.
ALL must be true:
- No observable behavior change (same inputs → same outputs)
- No public interface changes
- No new features, even small ones
- Explicit `/refactor` command used, OR task description contains only restructuring

**Refactor rules:**
- Planner documents: what is changing structurally, what must stay identical
- Implementer adds a `// REFACTOR:` comment on every changed block explaining the structural reason
- Tester runs the full suite before AND after — both runs must be identical pass/fail
- If any test changes are needed beyond import paths, STOP — this is no longer a pure refactor; escalate
- Reviewer checks: no new logic introduced, no behavior delta, no dead code added

### `/plan` Command
Forces COMPLEX classification on any request, regardless of apparent scope.

### `/research` Command
Forces COMPLEX classification AND explicitly triggers the Researcher even if the task
would otherwise be STANDARD. Use when you want a full feature audit before planning.

### `/hotfix` Command
Forces HOTFIX classification. Use only when something is broken in production right now.

### `/refactor` Command
Forces REFACTOR classification. Use when restructuring code with zero behavior change.

### `/audit` Command
Triggers the Security Auditor immediately on the current codebase state, bypassing all
other pipeline phases. Use for: spot checks mid-development, full audit before a release,
or auditing existing code not written in this session. Does not require an approved PLAN.md
or ARCH.md — audits whatever is currently in the codebase.

### `/status` Command
Read-only. Prints a formatted summary of the current SESSION_STATE.md without resuming
or continuing the pipeline. Use when returning to a project after time away.

Output format:
```
📊 SESSION STATUS
Project:  [name] @ [repo path]
Task:     [one-line goal]
Type:     [COMPLEX | STANDARD | HOTFIX | REFACTOR]

Pipeline:
  ✅ Phase -1  Researcher      COMPLETE
  ✅ Phase 0   Planner         COMPLETE
  ✅ Phase 1   Architect       COMPLETE
  🔄 Phase 2   Implementer     IN_PROGRESS — Phase 2 of 4
  ⏳ Phase 3   Tester          PENDING
  ⏳ Phase 4   Reviewer        PENDING
  ⏳ Phase 5   Security Audit  PENDING

Last step:  [description]
Next step:  [description]
Blockers:   [none | description]

To resume: confirm the next step above.
```

Does not modify any file. Does not continue the pipeline. Waits for user instruction.

---

## 🤖 AGENT ROSTER

Each agent is spawned as a subagent via the **Task tool** with an explicit model assignment.
The main session acts as coordinator only — it classifies, gates, and hands off.
Agents do all substantive work on their assigned model.

### Model Assignment Rationale

| Phase | Agent | Model | Reason |
|-------|-------|-------|--------|
| -1 | **Researcher** | `claude-sonnet-4-5` | Structured analysis, MoSCoW classification — no deep ambiguity reasoning needed |
| 0 | **Planner** | `claude-sonnet-4-5` | Question batching and requirement extraction — well-defined task |
| 1 | **Architect** | `claude-opus-4-5` | Cross-cutting design decisions, interface contracts, phase decomposition — highest reasoning demand in the pipeline |
| 2 | **Implementer** | `claude-sonnet-4-5` | Code generation against approved ARCH.md — spec is already resolved |
| 3 | **Tester** | `claude-sonnet-4-5` | Table-driven test generation and coverage analysis — pattern work |
| 4 | **Reviewer** | `claude-opus-4-5` | Finding subtle correctness bugs, design flaws, and missed edge cases requires depth |
| 5 | **Security Auditor** | `claude-opus-4-5` | Attack path reasoning cannot be pattern-matched — requires genuine adversarial thinking |

**Opus phases**: Architect (1), Reviewer (4), Security Auditor (5) — design and security correctness  
**Sonnet phases**: Researcher (-1), Planner (0), Implementer (2), Tester (3) — execution against resolved specs

### Task Tool Invocation Pattern

The coordinator spawns each agent using this pattern. Read the relevant skill file path
and pass it as the first instruction in the prompt:

```
Task(
  description="Phase -1: Researcher",
  model="claude-sonnet-4-5",
  prompt="""
    Read ~/.claude/skills/researcher/SKILL.md completely before acting.
    Task: [task description]
    Codebase: [project root]
    Write output to: .claude/RESEARCH.md
    When complete, announce: ✓ researcher complete
  """
)

Task(
  description="Phase 0: Planner",
  model="claude-sonnet-4-5",
  prompt="""
    Read ~/.claude/skills/planner/SKILL.md completely before acting.
    Read .claude/RESEARCH.md if it exists.
    Task: [task description]
    Write output to: .claude/PLAN.md
    Emit AWAITING_INPUT gate after presenting PLAN.md. Stop.
  """
)

Task(
  description="Phase 1: Architect",
  model="claude-opus-4-5",
  prompt="""
    Read ~/.claude/skills/architect/SKILL.md completely before acting.
    Read .claude/PLAN.md — this is the approved spec. Do not deviate.
    Write output to: .claude/ARCH.md
    Emit AWAITING_INPUT gate after presenting ARCH.md. Stop.
  """
)

Task(
  description="Phase 2: Implementer — Phase N: [name]",
  model="claude-sonnet-4-5",
  prompt="""
    Read ~/.claude/skills/golang-pro/SKILL.md completely before acting.
    Read .claude/ARCH.md — implement Phase N tasks only. Do not skip ahead.
    Run full build gate before handoff:
      go generate ./... (if //go:generate directives exist)
      go mod tidy && go build ./... && go vet ./... && golangci-lint run
    All must pass clean. Do not hand off with any failures.
    Announce: ✓ Phase N complete — handing to test-master
  """
)

Task(
  description="Phase 3: Tester — Phase N",
  model="claude-sonnet-4-5",
  prompt="""
    Read ~/.claude/skills/test-master/SKILL.md completely before acting.
    Test only the code from Phase N. Not everything.
    Mandatory: go test -race -count=1 -coverprofile=coverage.out ./...
    The -race flag is not optional.
    Write output to: .claude/TEST_REPORT.md
    All tests (with -race) must pass before handing to Reviewer.
  """
)

Task(
  description="Phase 4: Reviewer",
  model="claude-opus-4-5",
  prompt="""
    Read ~/.claude/skills/code-reviewer/SKILL.md completely before acting.
    Read .claude/PLAN.md acceptance criteria.
    Read .claude/TEST_REPORT.md.
    Write output to: .claude/REVIEW.md
    Emit AWAITING_INPUT gate after presenting verdict. Stop.
  """
)

Task(
  description="Phase 5: Security Auditor",
  model="claude-opus-4-5",
  prompt="""
    Read ~/.claude/skills/security-auditor/SKILL.md completely before acting.
    Audit only the changes in this phase. Check trigger conditions first.
    Write output to: .claude/SECURITY_AUDIT.md
    CRITICAL findings block commit. WARN is advisory.
  """
)
```

### Model Override (Project-Level)

Project CLAUDE.md can override any agent's model:

```markdown
## Model Overrides
# Upgrade Implementer to Opus for this project (complex domain logic):
Implementer model: claude-opus-4-5

# Downgrade Researcher to Haiku for fast codebase scanning:
Researcher model: claude-haiku-4-5-20251001
```

### Per-Agent Context Budget

Even with the right model, context must be managed. Each agent has a defined scope —
loading beyond it degrades quality and burns tokens without benefit.

| Agent | Load These Files | Do NOT Load |
|-------|-----------------|-------------|
| Researcher | Own skill file + project structure scan | All source files, other artifacts |
| Planner | Own skill file + RESEARCH.md + referenced interfaces | Full codebase |
| Architect | Own skill file + PLAN.md + domain interfaces only | Implementation files, test files |
| Implementer | Own skill file + ARCH.md (current phase only) + files being modified | Unrelated packages, all artifacts |
| Tester | Own skill file + phase tasks from ARCH.md + files being tested | RESEARCH.md, ARCH.md other phases |
| Reviewer | Own skill file + PLAN.md + TEST_REPORT.md + changed files only | Unchanged packages |
| Security Auditor | Own skill file + changed files + direct dependencies of changed files | Unrelated packages, RESEARCH.md |

**Hard rule**: No agent loads all skill files simultaneously. One skill per agent invocation.

### Skill Swap (Language Override)

Project-level CLAUDE.md can swap the Implementer skill only:

```markdown
## Skill Override
Implementer: ~/.claude/skills/rust-pro/SKILL.md
```

Planner, Reviewer, and Security Auditor are language-agnostic — never swapped.

---

## 🔍 PHASE -1 — RESEARCH

**Agent**: Researcher
**Skill**: `~/.claude/skills/researcher/SKILL.md` — read this before acting.
**Applies to**: COMPLEX tasks and `/plan` + `/research` commands.

**Summary:**
- Scan codebase — what exists, what will be affected, what can be reused
- Classify every feature (requested and missing) as MUST / SHOULD / COULD / WON'T
- Flag anything missing from the request that belongs in MUST or SHOULD
- Identify risks and conflicts that require a decision before planning begins
- Write `.claude/RESEARCH.md`
- Auto-proceed to Planner — no user approval gate here
- Planner **must** read RESEARCH.md before formulating any questions

**Key rule**: The Researcher does not recommend implementations. It investigates scope.
The Planner does not re-ask what RESEARCH.md already answered.

---

## 📋 PHASE 0 — DISCOVERY

**Agent**: Planner
**Skill**: `~/.claude/skills/planner/SKILL.md` — read this before acting.

**Summary of gate:**
- Ask all clarifying questions in one batched message
- Write `.claude/PLAN.md`
- Present it, ask for approval
- Do not proceed until approved

---

## 📐 PHASE 1 — ARCHITECTURE

**Agent**: Architect
**Skill**: `~/.claude/skills/architect/SKILL.md` — read this before acting.
**Applies to**: COMPLEX tasks only.

**Summary of gate:**
- Design only — no production code
- Write `.claude/ARCH.md` with: directory tree, interfaces, data flow diagram,
  dependency decision log, implementation phase breakdown
- Present it, ask for approval
- Do not proceed until approved

---

## 🔨 PHASE 2 — IMPLEMENTATION

**Agent**: Implementer
**Skill**: `~/.claude/skills/golang-pro/SKILL.md` — read this before acting.
**Override**: Project-level `CLAUDE.md` may specify an alternate skill file.

**Summary of gate:**
- Implement ONE phase at a time per ARCH.md
- Announce phase start and end
- `go build ./...` must pass before handoff
- Hand off to Tester — do not skip ahead

---

## 🧪 PHASE 3 — TEST

**Agent**: Tester
**Skill**: `~/.claude/skills/test-master/SKILL.md` — read this before acting.

**Summary of gate:**
- Test the phase just completed — not everything
- `go test -race ./...` + `go vet ./...` must pass
- Write `.claude/TEST_REPORT.md`
- On failure: fix loop with Implementer (max 3 iterations)
- On pass: hand off to Reviewer

---

## 🔍 PHASE 4 — REVIEW

**Agent**: Reviewer
**Skill**: `~/.claude/skills/code-reviewer/SKILL.md` — read this before acting.

**Summary of gate:**
- Full checklist: correctness, security, design, observability, maintainability, Go patterns
- NEEDS_CHANGES → return to Implementer (max 3 cycles)
- APPROVED → hand off to Security Auditor (Phase 5)

---

## 🔒 PHASE 5 — SECURITY AUDIT

**Agent**: Security Auditor
**Skill**: `~/.claude/skills/security-auditor/SKILL.md` — read this before acting.

**Activation**: Automatic after Reviewer approval when any of these are true:
- New/modified network listener or raw socket
- New/modified auth or authorization logic
- New/modified cryptographic operation
- External input ingested from any source
- New external dependency added
- `exec.Command` or `os/exec` used
- File path constructed from external source
- SQL query constructed or modified
- TLS configuration added or modified
- Secret, token, or credential handled
- New binary, daemon, or long-running service

If none apply: skip with explicit announcement. Do not audit for the sake of auditing.

**Domains covered**: Input validation & injection, auth & trust boundaries,
crypto & secrets, network exposure, dependency vulnerabilities.

**Summary of gate:**
- CRITICAL findings → return to Implementer, re-audit after fix (scoped to diff only)
- WARN findings → documented in SECURITY_AUDIT.md, do not block commit
- APPROVED → emit approval gate signal → proceed to commit

---

## 🧠 CONTEXT WINDOW MANAGEMENT

Claude Code has a finite context window. On large projects with multiple skill files,
artifact files, and source code open simultaneously, context pressure is real.
Ignoring it causes silent degradation — instructions get dropped, earlier decisions
get forgotten, and quality falls off without warning.

### Warning Signs of Context Pressure

- Responses get shorter and less structured than earlier in the session
- Agent stops following checklist items it followed earlier
- Questions are asked that were already answered in PLAN.md or ARCH.md
- Code produced diverges from ARCH.md decisions without acknowledgment

### Rules for Managing Context

**Before starting a long implementation phase:**
1. Write SESSION_STATE.md with full current pipeline status
2. Confirm the active artifacts are: PLAN.md, ARCH.md, current phase tasks only
3. Close (stop referencing) RESEARCH.md — it has served its purpose by Phase 2

**During implementation:**
- Load only the files needed for the current phase task
- Do not re-read entire codebases — read specific files relevant to the current task
- If a prior decision is unclear, read the specific artifact section — do not reconstruct from memory

**When context is running low (responses degrading):**
```
⚠️ CONTEXT LIMIT APPROACHING

Saving state before continuing.
Writing SESSION_STATE.md now with current progress.

Next session should resume from:
  Phase: [N]
  Last completed task: [description]
  Next task: [description]
  Read first: SESSION_STATE.md → PLAN.md → ARCH.md (Phase N section only)
```

Stop at a clean task boundary. Never stop mid-implementation of a task — finish the
current task, run the build, then checkpoint.

**Skill file loading strategy:**
- Each agent reads its own skill file at activation — not all skill files
- Do not load all skill files at session start
- Researcher loads `researcher/SKILL.md` only
- Implementer loads `golang-pro/SKILL.md` only (or the overridden skill)
- Cross-agent skill files are never needed simultaneously

---

## ✅ DEFINITION OF DONE

A feature is not done when the Reviewer approves. It is done when all of the following
are complete. The Reviewer is responsible for running this checklist before closing out.

### Code
- [ ] Commit made with confirmed conventional commit message
- [ ] All `.claude/` artifacts updated to final state
- [ ] `SESSION_STATE.md` pipeline status: all phases marked COMPLETE
- [ ] `SECURITY_AUDIT.md` verdict: APPROVED (or skipped with explicit reason)

### Documentation
- [ ] README updated if public-facing behavior changed
- [ ] Any ASCII/Mermaid architecture diagrams in the repo updated to reflect structural changes
- [ ] `go doc` output correct — no exported symbol without a godoc comment
- [ ] CHANGELOG.md updated (see § CHANGELOG Convention below)

### CHANGELOG Convention

Format: [keep-a-changelog](https://keepachangelog.com/en/1.1.0/) — `## [Unreleased]` section.
File: `CHANGELOG.md` at repo root. Create it if it doesn't exist.
Owner: **Reviewer agent** drafts the entry. User confirms before commit.

```markdown
## [Unreleased]

### Added
- [new capability user-visible]

### Changed
- [existing behavior that changed]

### Fixed
- [bug that was fixed]

### Security
- [any security-relevant change — always include if Security Auditor ran]

### Deprecated / Removed
- [only if applicable]
```

**Rules:**
- One entry per feature/fix, not per commit
- Plain English — written for a future developer, not for the commit log
- `Security` section is mandatory if `SECURITY_AUDIT.md` was produced for this change
- If the project has no `CHANGELOG.md`: create it with the standard header on first use
- HOTFIX entries go under `### Fixed` with a note: `(hotfix — root cause tracked in #N)`

### Commit Convention

All commits use the following format. This is the canonical definition — skill files reference this.

```
<type>(<optional scope>): <short summary>
```

| Type | Use for |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Maintenance, dependencies, configs |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement |
| `style` | Formatting, whitespace (no logic change) |
| `build` | Build system or external dependency changes |

**Scope** (optional): short identifier for the area of change — `api`, `worker`, `auth`,
`pipeline`, `web`, `docker`, `android`, etc. Match existing scopes in the repo's history.

**Rules:**
- Header only — no body or footer required
- Summary: lowercase, imperative mood (`add` not `added` or `adds`)
- No period at the end
- Total length ≤72 characters

**Examples:**
```
feat(api): add Prometheus metrics endpoint
fix(worker): prevent duplicate alert emails during cooldown
docs: add commit convention guide
refactor(pipeline): extract prefilter into separate package
test(auth): add table-driven tests for JWT validation
chore(docker): update Ollama image to latest
perf(llm): reduce timeout from 30s to 20s
```

### Cleanup
- [ ] No debug logging left behind (`slog.Debug` is fine; `fmt.Println` is not)
- [ ] No TODO comments added without a linked issue
- [ ] No commented-out code blocks

### Feature Branch (if applicable)
- [ ] Branch rebased or merged cleanly
- [ ] No merge conflicts left unresolved

### Follow-up Tasks
- [ ] Any COULD HAVE or WON'T HAVE items from RESEARCH.md logged as future issues
- [ ] Any HOTFIX follow-up tasks created (root cause addressed)
- [ ] Any WARN findings accepted in REVIEW.md tracked as known technical debt

When all boxes are checked: update `SESSION_STATE.md` status to `DONE` and announce:
```
✓ Feature complete. All done checklist items verified.
```

---

## ⚡ HOTFIX REVIEW CHECKLIST

Replaces full Phase 4 Review for HOTFIX tasks. Fast but not blind.

- [ ] Fix addresses exactly the reported failure — nothing more
- [ ] No unrelated changes snuck in
- [ ] Error is handled and logged — not silently swallowed
- [ ] All existing tests pass — no regressions
- [ ] Rollback plan exists (documented in commit message)
- [ ] A follow-up task is created to address root cause if this is a workaround

If any item fails: escalate. Do not commit a hotfix that introduces new risk.

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

Stop the loop. Report to user when ANY occurs:

1. Test failure not resolved after 3 Implementer iterations
2. Reviewer finding not resolved after 3 fix cycles
3. Fix breaks tests in another package (regression)
4. Making tests pass requires deviating from ARCH.md
5. New external dependency needed that wasn't in the plan
6. Security decision can't be resolved by existing constraints

**Escalation format:**
```
🚨 ESCALATION — Human Decision Required

Situation: [what is stuck]
Attempts: [N]
Tried: [brief list]
Root cause: [hypothesis]
Decision needed: [specific question]
Options:
  A) [option] — trade-off
  B) [option] — trade-off
```

### Phase Gate Summary

| Transition | Gate |
|------------|------|
| CLASSIFY → Phase -1 | Automatic (COMPLEX only) |
| Phase -1 → Phase 0 | Automatic (Planner reads RESEARCH.md first) |
| Phase 0 → Phase 1 | ✅ User approves PLAN.md |
| Phase 1 → Phase 2 | ✅ User approves ARCH.md |
| Phase 2 → Phase 3 | `go mod tidy` + `go build ./...` + `go vet ./...` + `golangci-lint run` clean |
| Phase 3 → Phase 4 | `go test -race ./...` passes, coverage thresholds met |
| Phase 4 → Phase 5 | ✅ Reviewer approves REVIEW.md |
| Phase 5 → Commit | ✅ No CRITICAL findings in SECURITY_AUDIT.md + user confirms commit message |
| NEEDS_CHANGES → Phase 2 | Automatic (≤3 loop budget) |
| CRITICAL_FINDINGS → Phase 2 | Automatic (≤3 loop budget, then escalate) |
| **HOTFIX: Phase 0 → Phase 2** | Planner produces PLAN.md; no approval gate |
| **HOTFIX: Phase 2 → Phase 3** | `go mod tidy` + `go build ./...` + `go vet ./...` clean |
| **HOTFIX: Phase 3 → Commit** | Tests pass + Hotfix checklist signed off |
| **REFACTOR: Phase 3** | Full suite must match pre-refactor results exactly |

---

## 📁 ARTIFACT MANAGEMENT

```
.claude/
  SESSION_STATE.md   ← written/updated by every agent; primary resume checkpoint
  RESEARCH.md        ← written by Researcher; read by Planner before questioning
  PLAN.md            ← written by Planner; approved before Architect
  ARCH.md            ← written by Architect; approved before Implementer
  TEST_REPORT.md     ← written/updated by Tester after each phase
  REVIEW.md          ← written/updated by Reviewer after each phase
  SECURITY_AUDIT.md  ← written by Security Auditor; CRITICAL findings block commit
```

**Rules:**
- Never delete mid-session
- Revisions append `## Revision N — [reason]`; old content preserved
- SESSION_STATE.md is the first file written and last file updated
- On resume: SESSION_STATE.md → then referenced artifacts → then act

---

## 🚫 GLOBAL PROHIBITIONS

Applies to all agents, all projects, all task types.

### Pipeline Integrity
```
1.  Never implement outside approved PLAN.md without asking
2.  Never classify TRIVIAL to dodge the pipeline on ambiguous work
3.  Never commit with failing or skipped tests
4.  Never introduce an external dependency without user approval
5.  Never ask clarifying questions one at a time — batch them
6.  Never produce code without stating what you're about to do and why
7.  Never loop more than 3 times without escalating
8.  Never make architectural decisions silently — surface them
9.  Never hallucinate package APIs — check with go doc or say you're unsure
10. Never silently discard an error
11. Never continue after emitting AWAITING_INPUT
```

### The Silent Deviation Anti-Pattern

This is the most insidious failure mode. It happens when an agent hits an obstacle —
a missing tool, an unavailable dependency, an environment issue, an ambiguous requirement —
and **silently substitutes an alternative** instead of stopping to ask.

It feels helpful. It is not. It violates the user's approved decisions without their knowledge,
and the user only discovers the substitution after the fact, when the work has to be redone.

**Every approved decision in PLAN.md, ARCH.md, or explicit user instruction is a contract.**
When an obstacle threatens that contract, there is exactly one valid response: stop and report.

#### Situations That Trigger This (non-exhaustive)

| Obstacle | Wrong response | Correct response |
|----------|---------------|-----------------|
| Approved tool/library not in PATH | Switch to alternative silently | Stop. Report. Ask. |
| Approved template engine has a compile error | Fall back to stdlib alternative | Stop. Report the error. Ask. |
| Approved DB driver doesn't support a feature | Use a different driver | Stop. Surface the gap. Ask. |
| ARCH.md interface won't work as designed | Redesign it silently | Stop. Escalate as architectural deviation. |
| Required CLI tool not installed | Skip the step or use workaround | Stop. List what's missing. Ask. |
| Approved package has no method you expected | Use a different package | Stop. Check go doc first. Then ask. |
| Environment missing a required capability | Work around it | Stop. Report the constraint. Ask. |
| User's instruction is ambiguous mid-task | Pick the most likely interpretation | Stop. Ask for clarification. |
| Two requirements conflict | Resolve it your way | Stop. Name the conflict explicitly. Ask. |

#### The Correct Escalation Format for Deviations

```
⛔ DEVIATION BLOCKED — Human Decision Required

Approved decision: [exact thing that was agreed on — library, tool, pattern, design]
Obstacle encountered: [what specifically prevents using it]
What I was about to do: [the substitution I considered]
Why I stopped: [that substitution was not approved]

Options:
  A) [resolve the obstacle — e.g. install the tool, fix the config] — keeps approved decision
  B) [approved alternative, if one exists] — requires updating PLAN.md/ARCH.md
  C) [other] — trade-off

Waiting for your decision.
```

Then emit AWAITING_INPUT and stop.

**The apology trap**: If you find yourself writing "I apologize, I should have asked first"
after making a silent substitution — that is a lagging indicator. The prohibition is on making
the substitution at all, not on apologizing afterward. Stop before acting, not after.

---

## 📊 SESSION STARTUP

```
1. Check for project-level CLAUDE.md at repo root
   → Found: read it; note Project Identity (Name, Repo root)
   → Not found: you are in a project without a local override; global rules apply

2. Check .claude/SESSION_STATE.md
   → Found:     Verify Project.Name matches current repo. If mismatch — STOP.
                Different project's state file. Do not resume. Announce mismatch.
   → Not found: Check .claude/PLAN.md
       → Found:     Read PLAN.md. Check Task type field.
                    If COMPLEX (has ARCH.md): "Found PLAN.md. Resuming from Phase 1 (Architect). Approve?"
                    If STANDARD (no Architect): "Found PLAN.md. Resuming from Phase 2 (Implementer). Approve?"
       → Not found: "Ready. What are we building?"

3. Do NOT ask "How can I help you today?"
4. Do NOT summarize these instructions
5. Classify the first task immediately
```

### Multi-Repo Isolation Rules

Each project's `.claude/` directory is scoped to that project only.

```
~/projects/mantis/.claude/      ← Mantis artifacts only
~/projects/archibald/.claude/   ← Archibald artifacts only
~/projects/logdrop/.claude/     ← logdrop artifacts only
```

**Never** read or reference `.claude/` artifacts from a different project directory.
**Always** verify `SESSION_STATE.md` Project.Name matches the current working directory
before resuming. Stale state from a different project will corrupt the pipeline.

If you are unsure which project you are in:
```bash
pwd  # confirm working directory
cat .claude/SESSION_STATE.md | grep "^## Project"  # confirm state belongs here
```

### SESSION_STATE.md Format

Written and updated by each agent at phase completion. Lives at `.claude/SESSION_STATE.md`.

```markdown
# SESSION_STATE.md
Last updated: [RFC3339]

## Project
Name: [project name — must match project CLAUDE.md]
Repo: [absolute path to repo root]

## Current Task
[Goal from PLAN.md — one sentence]

## Task Type
COMPLEX | STANDARD | HOTFIX | REFACTOR

## Pipeline Status
| Phase | Agent | Model | Status | Artifact |
|-------|-------|-------|--------|----------|
| -1 | Researcher | claude-sonnet-4-5 | COMPLETE | .claude/RESEARCH.md |
| 0 | Planner | claude-sonnet-4-5 | COMPLETE | .claude/PLAN.md |
| 1 | Architect | claude-opus-4-5 | COMPLETE | .claude/ARCH.md |
| 2 | Implementer | claude-sonnet-4-5 | IN_PROGRESS — Phase 2 of 4 | — |
| 3 | Tester | claude-sonnet-4-5 | PENDING | — |
| 4 | Reviewer | claude-opus-4-5 | PENDING | — |
| 5 | Security Auditor | claude-opus-4-5 | PENDING | — |

## Last Completed Step
Implementer finished Phase 1: Core Domain Types. Tests passed.

## Next Step
Implementer: start Phase 2: Engine Logic
  Tasks:
  - [ ] Implement Evaluator in internal/engine/
  - [ ] Implement rule matching logic

## Blockers
[none | description of any open escalation]
```

**Rules:**
- Every agent writes SESSION_STATE.md at the end of its phase
- On resume: read SESSION_STATE.md, then read all referenced artifacts before acting
- Do not trust memory — re-read the artifacts; the session context may be stale

---

## 🗂️ PROJECT-LEVEL OVERRIDE PATTERN

Create a `CLAUDE.md` at the project root to override globals. Inherits everything not
explicitly overridden. Project-level rules always win.

```markdown
# CLAUDE.md  (project root — overrides ~/.claude/CLAUDE.md)

## Project Identity
Name: mantis
Repo root: ~/projects/mantis
Description: Active-defense honeypot platform

## Skill Override
# Swap Implementer language skill only (Planner/Reviewer/SecurityAuditor are never swapped):
Implementer: ~/.claude/skills/rust-pro/SKILL.md

## Model Overrides
# Upgrade Implementer to Opus for complex domain logic:
Implementer model: claude-opus-4-5
# Downgrade Researcher to Haiku for fast codebase scanning:
Researcher model: claude-haiku-4-5-20251001

## Phase Overrides
# Force all STANDARD tasks to COMPLEX (require ARCH.md):
Minimum task classification: COMPLEX

## Security Auditor Sensitivity
# Add extra trigger conditions beyond the global defaults:
Security audit also triggers on changes to:
  - internal/fingerprint/
  - internal/deception/
  - any file importing golang.org/x/crypto

## Additional Prohibitions
- No unsafe{} without explicit approval and audit note in SECURITY_AUDIT.md
- No hardcoded fingerprint signatures — load from config

## CHANGELOG Convention
# Override only if you need different sections or format from the global convention.
# Global convention: keep-a-changelog, Reviewer drafts, Security Auditor commits.
# See ~/.claude/CLAUDE.md § CHANGELOG Convention for full rules.
```

---

*Version: 12.0.0 | 2026-03-08*
*Skill directory: ~/.claude/skills/*
