---
subjects:
  - apex-job/src/monitor/lwc/**
  - jest.config.js
phases: [design, implementation]
kind: gotcha
trigger: an LWC async method lets a rejected promise escape and a jest test must prove the component survives the rejection
evidence:
  - apex-job/src/monitor/lwc/engineControls/engineControls.js:46
  - apex-job/src/monitor/lwc/engineControls/__tests__/engineControls.test.js:97
source: { run: apply-perf-review-findings, phase: implementation, date: 2026-11-26 }
status: active
supersedes: []
last-verified: 2026-11-26
---
# 003 — sfdx-lwc-jest fails a test on any unhandled rejection

## Context

The design kept `try { await refresh() } finally { re-arm }` with no `catch`, planning a test-scoped `process.on('unhandledRejection')` handler. Three variants of that handler all failed: jest still failed the test with the rejected error's message.

## Lesson

Under sfdx-lwc-jest (Jest 29, jest-circus), a listener registered from inside the test sandbox does not intercept the rejection jest-circus tracks, so "let it escape" designs cannot be tested green.

## How to apply

Design LWC async handlers with an explicit `catch` that logs with context (`console.error('<component>: <action> failed', error)`) and keeps going.
Test it with `jest.spyOn(console, 'error')`, asserting the call and restoring the spy.
Do not plan on process-level rejection handlers in LWC jest tests.

## Evidence

`engineControls.js:46` and the `givenRejectedCall_whenIntervalElapses_thenErrorLoggedAndPollingResumes` test at `engineControls.test.js:97`.
