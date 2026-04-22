# Loop Automation

How to run slices of the Current Batch through an autonomous `/loop` with
drift protection and human override.

## Setup

Paste the prompt below into a new Claude Code chat. It will read existing
scaffolding (`docs/project-rhythm.md`, `docs/execution-plan.md`, decision
and architecture docs, Current Batch) and produce two artifacts: a slice
backlog in the Current Batch file, and a `/next-slice` slash command. It
will not start the loop — that step is manual.

```
I want to set up an autonomous /loop pipeline that works through slices of the current
batch one at a time, re-entering the backlog fresh each firing so we don't accumulate
drift inside a single long conversation.

## Existing scaffolding (read first, don't re-invent)

- docs/project-rhythm.md — defines sources of truth and refresh triggers. The
  `/next-slice` command MUST honor these triggers.
- docs/execution-plan.md — epic roadmap and current epic
- docs/decision/ — durable product/contract truth
- docs/architecture/ — intended structure
- Recent commits reference a "Current Batch" concept (see commit c6ff49d:
  "docs: refresh Current Batch after Epic 3d"). Find where Current Batch lives
  and how entries are shaped. Do not create a parallel system — use what exists.

## What to produce

1. **Slice backlog for the current batch** — written into whatever file already holds
   the Current Batch. Each slice must:
   - Be small enough to finish in one turn (one coherent change, one commit).
   - Have an explicit "done" signal (file created, test passes, command output matches).
   - Reference the relevant decision/architecture doc if one exists.
   - Include a "refresh check" note if completing the slice could trigger a
     project-rhythm.md refresh (epic boundary, durable rule change, structural
     boundary change, material impact on next batch).

2. **A `/next-slice` slash command** (in .claude/commands/ — verify the right
   location for this repo's setup) that on each firing:
   a. Re-reads the Current Batch file fresh (do not rely on prior turn memory).
   b. Re-reads docs/project-rhythm.md, docs/execution-plan.md, and the current
      epic's architecture/decision docs. This is the drift guard.
   c. Picks the top unstarted slice.
   d. If any project-rhythm.md refresh trigger fired since the last slice,
      STOP and surface it to the user instead of silently proceeding.
   e. Implements the slice.
   f. Verifies the done signal explicitly.
   g. Marks the slice done in the batch file.
   h. Commits with a message that follows the repo's existing commit style
      (see recent commits for format — e.g. "feat(epic-3d): ...").
   i. If the slice was the last in the current batch, STOP rather than
      guessing the next batch — batch planning is a human decision.

3. **A short README** at the top of the Current Batch file explaining the loop
   contract: how slices are shaped, what /next-slice does, how to stop it.

## Constraints

- Do NOT start the loop yourself. Only set up the pieces. I'll kick it off.
- Do NOT expand scope beyond the current batch. If the current batch is empty
  or unclear, stop and ask.
- Do NOT duplicate or replace existing planning docs. Extend them.
- If something in the existing scaffolding is ambiguous (e.g. where exactly
  Current Batch lives, or whether slash commands go in .claude/commands/),
  ask before guessing.

Start by reading the files listed above and reporting back what you found
(where Current Batch lives, what the current epic is, what slices are already
drafted vs. need writing) before producing anything.
```

## Execution Modes

### Manual — dry-run the machinery

Drive each slice yourself to confirm `/next-slice` behaves before adding
autonomy.

1. Open a chat. Run `/next-slice`.
2. Verify: right slice picked? Right docs re-read? Sane plan?
3. Let it implement, verify, commit.
4. Review the diff and commit message.
5. Repeat 2–3 times until trusted.

A bug in a single-turn run becomes 20 bugs in a loop — catch it here.

### Semi-automated — fixed interval

```
/loop 5m /next-slice
```

- Runs `/next-slice`, waits 5 minutes, fires again.
- Long enough to review each commit before the next slice starts.
- Glance, course-correct, or stop between firings.

### Fully automated — self-paced

```
/loop /next-slice
```

- Claude picks the delay each turn (60s–3600s floor/ceiling).
- Stops when `/next-slice` returns "no more slices" or when a refresh trigger
  fires — the command's contract ends the loop by not scheduling the next
  wakeup.

## Control Levers

| Action | When | How |
|---|---|---|
| Hard stop | Going off the rails | Esc / `/stop`, or type a message |
| Redirect mid-loop | Add guidance without stopping | Type between firings — next turn sees it |
| Pause for review | Inspect state without killing | Message the chat "don't start the next slice, I want to review" before the wake fires |
| Adjust the backlog | Slice is wrong or missing | Edit the Current Batch file directly. `/next-slice` re-reads it each firing |
| Force a refresh cycle | New learning should update docs | Edit relevant decision/architecture doc. Next `/next-slice` detects the trigger and stops |
| Kill-switch | Halt from another terminal | `touch .loop-pause` at repo root. `/next-slice` exits immediately if the file exists |
| End cleanly | Done for the day | `/stop` after the current slice, or let it hit end-of-batch naturally |

## Recommended Progression

1. Run `/next-slice` manually 3 times. Verify doc re-reading, slice selection,
   clean commits, correct stopping.
2. Run `/loop 5m /next-slice` for a half-batch. Supervised but not driven.
3. Switch to `/loop /next-slice` only after steps 1–2 pass without corrections.

The failure mode to avoid: jumping straight to full auto, going AFK, returning
to 8 commits of subtly wrong work from a bug that only appears after several
iterations.

## Drift Protection Summary

The loop's drift defenses, in order of strength:

1. `/next-slice` re-reads canonical docs on every firing — no reliance on
   prior-turn memory.
2. `project-rhythm.md` refresh triggers halt the loop when durable rules,
   structural boundaries, or epic boundaries shift.
3. End-of-batch halts the loop — batch planning stays a human decision.
4. The kill-switch file gives an out-of-band halt that doesn't require
   catching the chat at the right moment.
