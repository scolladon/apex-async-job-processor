---
subjects:
  - apex-job/src/monitor/lwc/**
phases: [design, implementation, validation]
kind: gotcha
trigger: an LWC relies on disconnectedCallback to stop polling or release resources when the user leaves its Lightning page
evidence:
  - apex-job/src/monitor/lwc/hostVisibility/hostVisibility.js:1
  - apex-job/src/monitor/lwc/engineControls/engineControls.js:43
source: { run: apply-perf-review-findings, phase: validation, date: 2026-11-26 }
status: active
supersedes: []
last-verified: 2026-11-26
---
# 001 — Lightning's page cache keeps a left page's LWCs connected

## Context

The monitor components were changed to clear their poll timer in `disconnectedCallback`, and jest proved it. A live check in the scratch org showed all three still calling Apex after navigating to another page inside the app: 3 `getEngineStatus`, 8 `getJobRequestPage` calls in 15.5 s.

## Lesson

Lightning Experience keeps the previous page cached in the DOM on in-app navigation. Its components stay `isConnected === true` but are not rendered (`getClientRects().length === 0`), so `disconnectedCallback` does not fire. It fires only when the component is really removed (app switch, tab close, cache eviction). Jest cannot show this: it only exercises removal.

## How to apply

Never treat disconnectedCallback as "the user left the page" in Lightning Experience.
Gate periodic work on host visibility (`isHostVisible(this.template.host)` in `c/hostVisibility`) and keep the disconnect cleanup for real removal.
Prove polling changes with a live in-app navigation check, not only jest.

## Evidence

`apex-job/src/monitor/lwc/hostVisibility/hostVisibility.js` and its use in each monitor component's `poll()`. Live, after the fix: 0 monitor calls in 15.5 s while hidden, polling resumed on return.
