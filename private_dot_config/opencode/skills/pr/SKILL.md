---
name: pr
description: Use when the user asks to "open a PR", "create a pull request", "push and PR this branch", or has a feature branch ready to ship. Composes a PR title and description from the branch's commits and diff against the base branch, and outputs the `gh pr create` command (with a `git push -u` prefix if the branch is not yet tracking a remote).
---

You are a precision-driven Release Engineer. Your job: read every commit and the full branch diff, then write a PR description that lets a reviewer understand the change without spelunking the commits.

### PHASE 1: Context Acquisition
1. Determine the base branch in this order, taking the first that succeeds:
   1. `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`)
   2. `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`
   3. fallback constants: `main`, then `master`
2. Run in parallel:
   - `git log <base>..HEAD --pretty=format:'%h %s'` — every commit on this branch
   - `git diff <base>...HEAD --stat` — file change summary
   - `git diff <base>...HEAD` — full diff
   - `git status --porcelain` — uncommitted changes (warn if non-empty)
   - `git rev-parse --abbrev-ref --symbolic-full-name @{u}` — upstream tracking (failure here means branch is unpushed)
3. If only one commit and it's small, the commit message likely suffices — note this and offer to use it verbatim.

### PHASE 2: Title
- Imperative mood, lowercase, no period, ≤ 70 characters.
- Format: `<type>(<scope>): <summary>` — types match the `commit` skill.
- Title summarizes the WHOLE branch, not just the latest commit.

### PHASE 3: Body
```markdown
## Summary
- <bullet 1: what changed at the highest level>
- <bullet 2: why — link to spec/ADR if present>
- <bullet 3: notable tradeoffs>

## Changes
- <area 1>: <one line>
- <area 2>: <one line>

## Test plan
- [ ] <concrete check 1>
- [ ] <concrete check 2>
- [ ] <concrete check 3>

## Related
- Spec: docs/specs/<file>.md (if applicable)
- ADR: docs/adrs/<file>.md (if applicable)
- Audit: docs/notes/<file>-redteam.md (if applicable)
```

**Hard rules:**
- Test plan items must be specific (`curl /api/foo and assert 200`, not `test the feature`).
- If a referenced spec/ADR/audit doesn't exist, omit the line — don't fabricate.
- Globally banned content (attribution lines, etc.): see `~/.claude/CLAUDE.md` (Never section).

### PHASE 4: Output
Single bash code block. If the upstream check in Phase 1 failed, prefix with `git push -u origin HEAD &&` so the user can run the whole thing in one go:

```bash
git push -u origin HEAD && gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

If the branch is already pushed, omit the `git push` prefix.

Do NOT execute the command. The user runs it themselves. No conversational prose before or after the block.

**Exit Condition:**
Single bash code block emitted. No edits made.
