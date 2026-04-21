# Project Rhythm

## Purpose

Define where planning truth lives and when it must be refreshed.

## Sources Of Truth

- `docs/decision/`
  - durable product and contract truth
- `docs/architecture/`
  - intended implementation structure
- `docs/execution-plan.md`
  - roadmap and sequencing
- issue tracker
  - operational execution queue

## Refresh Triggers

Always refresh when:
- a durable rule changes
- a structural boundary changes
- the next planned batch is materially affected by new learning
- an epic boundary is crossed

## Practical Rule

If a future task would likely be written differently because of what was just
learned, update the plan and docs now.
