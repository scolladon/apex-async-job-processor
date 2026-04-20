# Extract watcher scheduling constants — Design

`ApexJobWatcher.schedule()` contains a loop that schedules twelve cron triggers
covering every five-minute slot of an hour:

```apex
for (Integer i = 0; i < 60; i += 5) {
  System.schedule(...);
}
```

The literal `60` and `5` are semantically meaningful — "there are 60 minutes per
hour" and "run the watcher every 5 minutes" — but the code expresses neither.
A reader has to reverse-engineer the intent. This change extracts both values
into named constants on `ApexJobConstant` so the loop reads as its own comment.

## Behavior

No runtime change. The loop still schedules the same 12 cron triggers at the
same cadence. Pure readability refactor.

## Data Model

None — new constants live in an Apex class, not on an SObject.

## Algorithm / Logic

Before:

```apex
for (Integer i = 0; i < 60; i += 5) {
  System.schedule(..., '0 ' + i + ' * ? * * *', new ApexJobWatcher());
}
```

After:

```apex
for (Integer i = 0; i < ApexJobConstant.MINUTES_PER_HOUR; i += ApexJobConstant.WATCHER_INTERVAL_MINUTES) {
  System.schedule(..., '0 ' + i + ' * ? * * *', new ApexJobWatcher());
}
```

The cron expression string itself (`'0 ' + i + ...`) is untouched — `i` still
ranges over `{0, 5, 10, ..., 55}`.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| Constants | `apex-job/src/engine/domain/classes/ApexJobConstant.cls` | Add `MINUTES_PER_HOUR = 60` and `WATCHER_INTERVAL_MINUTES = 5`. |
| Watcher | `apex-job/src/engine/adapter/ApexJobWatcher.cls` | Replace literal `60` and `5` in the `schedule()` loop with the new constants. |

Existing `ApexJobWatcherTest` exercises `schedule()` and asserts twelve cron
triggers are created — it continues to pass because the loop arithmetic is
unchanged (`60 / 5 = 12`).

## Edge cases

- **Test asserts 12 schedules**: verified that the count derives from `60/5`, so
  the new constants must produce the same quotient. Any future change to
  `WATCHER_INTERVAL_MINUTES` must be paired with a test update.
- **Constants live in `ApexJobConstant`, not on the watcher**: intentional. The
  repo already centralizes numeric constants there (`DEFAULT_MAX_CHUNK_SIZE`,
  `RATE_WINDOW_MS`); a watcher-local duplicate would split the convention.

## Rollback

`git revert <commit-sha>` restores the literals. No data migration, no test
rewrite needed (tests never referenced the constants).

## Open questions

None.
