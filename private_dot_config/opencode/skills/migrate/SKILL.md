---
name: migrate
description: Use when the user asks to "write a migration", "add a column", "rename/drop a column", "change the schema", or otherwise needs a backward-compatible database schema change. Designs forward+rollback migration pairs, classifies safe vs breaking changes, splits breaking changes across deploys, and writes an accompanying note documenting the deploy sequence.
---

Design backward-compatible schema changes. Assume old and new code both run against the schema mid-deploy.

## Phase 1: Detect tooling

Check `./CLAUDE.md` for declared migration tool. Check repo for `migrations/` with `*.up.sql`/`*.down.sql` (golang-migrate), `migrate.hcl` (atlas), or `db/queries/` with `sqlc.yaml` (sqlc+golang-migrate). If unclear, ask once. Default: golang-migrate.

## Phase 2: Classify changes

**Safe** (works alongside old code):
- Adding nullable column, new table, non-unique index concurrently
- Adding enum value at end (Postgres)

**Breaking** (multi-step required):
- Dropping column → 3 deploys: stop reading → stop writing → drop
- Renaming column → add new + dual-write + backfill + swap reads + drop old
- Adding NOT NULL without default → add nullable, backfill, SET NOT NULL
- Tightening constraints → ADD CONSTRAINT NOT VALID, then VALIDATE
- Incompatible type changes

Halt on breaking changes until user approves the multi-deploy plan.

## Phase 3: Write migrations

Forward + rollback pair per step:
- `migrations/<NNNN>_<slug>.up.sql`
- `migrations/<NNNN>_<slug>.down.sql`

Pad numbers to 4 digits, continuing from highest existing. Use `IF NOT EXISTS`/`IF EXISTS` where the tool allows.

## Phase 4: Backfills

If data movement is needed:
- Small dataset: include in `*.up.sql`.
- Large dataset: write `cmd/backfill_<slug>/main.go` — respects `context.Context`, batched, idempotent. Reference in deploy sequence.

State which approach and why.

## Phase 5: Write note

Create `docs/notes/YYYYMMDD_<slug>-migration.md` per docs-convention. Include `related_spec:` if applicable. Sections:
1. **Change Summary**
2. **Compatibility Analysis** — which old code paths work mid-deploy
3. **Deploy Sequence** — exact order: migration → deploy → backfill → next migration
4. **Rollback Plan** — what `down.sql` does, what data is lost
5. **Files** — list of `.sql` files and any `cmd/backfill_*` programs

Update `docs/index.md`.
