# Move watcher anon-apex snippet — Design

`ApexJobWatcher.cls` opens with a 7-line `/** */` block that embeds an executable
anonymous-apex snippet (kill pre-existing `Async Job Watcher` cron triggers, then
call `ApexJobWatcher.schedule()`). The snippet lives inside a production class
comment, which means:

- It cannot be executed directly — operators must copy-paste it into an anonymous
  apex window or script file, re-introducing the risk of transcription errors.
- It silently drifts from reality when the class or cron-job name changes.
- It adds non-executable noise to the top of a production file.

The fix is to move the snippet into its own `.apex` file under `scripts/apex/`,
reference it from operator docs, and delete the comment block.

## Behavior

No runtime change. The watcher class behaves identically after the move. The
snippet becomes an executable operator tool rather than a reference-only comment.

## Data Model

None.

## Algorithm / Logic

None — file move plus comment deletion.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| Scripts (new directory) | `scripts/apex/restart-watcher.apex` | Create — contains the anon-apex that was in the comment. |
| Watcher class | `apex-job/src/engine/adapter/ApexJobWatcher.cls` | Delete lines 1–7 (the `/** */` comment block). |

`scripts/` is not inside any `sfdx-project.json` `packageDirectories` entry, so
the new file is never deployed. Verified against `sfdx-project.json` which lists
only `apex-job/src` and `apex-job/test`.

No `.forceignore` change required for the same reason.

## Edge cases

- **Snippet drift**: the anon-apex snippet references `Async Job Watcher%` and the
  `ApexJobWatcher` class name. If either renames later, the script silently breaks.
  Mitigation: add a comment at the top of the script identifying the cron-job
  name literal and the class it schedules.
- **Permissions**: running the script requires the org's standard `Modify All Data`
  / author-apex permission. Out of scope — same requirement as copy-pasting the
  snippet today.

## Rollback

`git revert <commit-sha>` restores the comment block and removes the script file.
No data migration, no consumer-facing API impact.

## Open questions

None.
