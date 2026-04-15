# AGENTS.md — `spoke/` Execution Override

> This file exists to make execution cadence explicit inside the `spoke/` working directory.
> Project-wide guidance still lives in `../CLAUDE.md`.

## Apply Root Guidance First

- Read `../CLAUDE.md` as the primary project guide.
- Treat this file as a narrow override for execution behavior inside `spoke/`.

## Continuous Execution Rule

- When the user clearly authorizes execution with phrases like `继续`、`继续推进`、`go on`、`执行所有任务`、`你来推动就行`, continue executing the agreed workstream without repeatedly asking for routine approval.
- Do not pause to ask for confirmation before ordinary code edits, document edits, verification runs, or planned implementation steps once that authorization exists.

## Only Ask When Truly Needed

Pause and ask only when:

- the next action is destructive or difficult to reverse
- the next action would materially change agreed scope or direction
- there is a high-risk ambiguity that cannot be resolved from local context

## Interactive Skill Routing

- `gsd-discuss-phase` is a discussion-first workflow and will naturally surface questions unless it is run in a non-interactive mode.
- If the user's real intent is continuous execution rather than interactive clarification, prefer execution-oriented workflows or the `--auto` / non-interactive path where available.

## Preferred Behavior

- Favor completed batches over frequent mid-task check-ins.
- Treat explicit continuous-execution authorization as stronger than generic “ask before coding” defaults.
- If runtime-enforced Plan Mode is active, follow runtime mode; otherwise default to execution continuity.
