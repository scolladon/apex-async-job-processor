# Rename finalizer kill predicate — Design

`AsyncApexJobExecutor.execute(FinalizerContext)` checks `shouldTreatException(ctx)`
before synthesizing a `KILLED` result for the last in-flight chunk. The method
name reads as "should [we] treat [this] exception?" — it does not describe what
it answers. The actual semantic is: "was the last chunk killed by the platform
before its result could be recorded?" This change renames the predicate to
`wasLastChunkKilled` so its call site reads as its own explanation.

## Behavior

No runtime change. Identical return values, identical semantics, identical call
site ordering. Pure rename.

## Data Model

None.

## Algorithm / Logic

None — pure rename, identical body.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| Finalizer predicate | `apex-job/src/engine/application/AsyncApexJobExecutor.cls` | Rename `shouldTreatException` → `wasLastChunkKilled` at both the declaration (line 84) and the single call site (line 57). |

Grep confirms the method is `private` and has **no external references** (no test,
no other production class calls it), so the rename is safe and self-contained.

## Edge cases

- **Private method**: rename cannot break any caller outside the class.
- **Parameter rename**: the parameter is currently `ctx`; opportunistically renamed
  to `finalizerContext` in the same commit for clarity (the call site already uses
  `finalizerContext` as the variable name).

## Rollback

`git revert <commit-sha>` restores the old name and parameter.

## Open questions

None.
