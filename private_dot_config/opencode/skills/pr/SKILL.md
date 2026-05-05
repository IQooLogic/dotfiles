---
name: pr
description: Use when the user asks to "open a PR", "create a pull request", "push and PR this branch", or has a feature branch ready to ship. Composes a PR title and description from the branch's commits and diff against the base branch, and outputs the `gh pr create` command (with a `git push -u` prefix if the branch is not yet tracking a remote).
---

Compose a PR from branch history. Output the `gh pr create` command. Do not execute.

## Phase 1: Acquire context

1. Determine base branch: `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`) → `gh repo view --json defaultBranchRef` → fallback `main` → `master`.
2. Run in parallel:
   - `git log <base>..HEAD --pretty=format:'%h %s'`
   - `git diff <base>...HEAD --stat`
   - `git diff <base>...HEAD`
   - `git rev-parse --abbrev-ref --symbolic-full-name @{u}` — failure means unpushed
3. Warn if uncommitted changes (`git status --porcelain` non-empty).

## Phase 2: Compose

**Title:** `<type>(<scope>): <summary>` — imperative, ≤70 chars, summarizes whole branch.

**Body:**
```markdown
## Summary
- <what changed at highest level>
- <why — link spec/ADR if present>
- <notable tradeoffs>

## Changes
- <area 1>: <one line>
- <area 2>: <one line>

## Test plan
- [ ] <concrete check>
- [ ] <concrete check>

## Related
- Spec: docs/specs/<file>.md (if applicable)
- ADR: docs/adrs/<file>.md (if applicable)
- Audit: docs/notes/<file>-redteam.md (if applicable)
```

Test plan items must be specific. Don't fabricate references — omit if nonexistent.

## Phase 3: Output

Single bash block. If unpushed, prefix with `git push -u origin HEAD &&`:

```bash
git push -u origin HEAD && gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

If `gh` not on PATH: `WARN: gh CLI not installed`. Output the PR title and body as text instead.
