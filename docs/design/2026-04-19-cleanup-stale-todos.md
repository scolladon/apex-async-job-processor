# Cleanup stale TODO comments — Design

Two `// TODO` comments in the engine reference a speculative future refactor ("move
this into a JobRequest/JobDescription domain class") that has been evaluated and
rejected. The comments are misleading — the referenced domain classes do not exist
and are not planned — and violate the repo's "no dead comments" rule
(`CLAUDE.md` → "no commented-out TODOs left behind"). This change removes the two
comments without touching the code they annotate.

## Behavior

No behavior change. Pure cosmetic cleanup; the annotated code keeps functioning
identically.

## Data Model

None.

## Algorithm / Logic

None — pure comment deletion.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| `JobExecutable` | `apex-job/src/engine/domain/classes/JobExecutable.cls` | Delete line 36: `// TODO Part of the JobDescription domain` |
| `JobRepositoryImpl` | `apex-job/src/engine/adapter/JobRepositoryImpl.cls` | Delete line 92: `// TODO part of the JobRequest Domain` |

A third TODO exists at `JobExecutable.cls:58` (`// TODO Part of the JobRequest__c domain`).
That one is intentionally left in place for this PR — it will be removed by the
upcoming `safe-argument-deserialization` work, which extracts the annotated
`getArgument` method into a dedicated `JobRequestArgumentParser` class. Removing
it here would orphan context the next reviewer needs.

## Edge cases

- None. The two deletions are literal comment removals with no syntactic impact.
- Prettier / lint / existing unit tests continue to pass without modification.

## Rollback

`git revert <commit-sha>` cleanly restores both lines. No data migration, no feature
flag, no consumer-facing API impact.

## Open questions

None.
