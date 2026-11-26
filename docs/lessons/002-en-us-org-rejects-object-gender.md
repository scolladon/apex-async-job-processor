---
subjects:
  - config/project-scratch-def.json
  - apex-job/src/engine/domain/objects/**
phases: [implementation, validation]
kind: trap
trigger: a scratch definition or target org uses a gender-neutral language such as en_US while object metadata carries a <gender> element
evidence:
  - config/project-scratch-def.json:4
  - apex-job/src/engine/domain/objects/JobRequest__c/JobRequest__c.object-meta.xml
source: { run: apply-perf-review-findings, phase: validation, date: 2026-11-26 }
status: active
supersedes: []
last-verified: 2026-11-26
---
# 002 — An en_US org rejects object metadata that carries a gender

## Context

The scratch definition gained `"language": "en_US"` so tests run under an English admin user. The fresh-org deploy then failed, and `sf` reported only `Unable to parse deploy diagnostic with empty problem` on the CustomIndex, which pointed at the wrong component.

## Lesson

The real failure was `Cannot specify a gender for a gender neutral language` on both custom objects, from `<gender>Feminine</gender>` written by a French-language org. Every dependent component then failed, and the CLI crashed on the first empty diagnostic instead of listing them.

## How to apply

Keep object metadata free of `<gender>` (and other language-specific label attributes) so it deploys under any org language.
On an empty-problem deploy diagnostic, re-run with `--json` and read `result.details.componentFailures`.
The component named in the empty diagnostic is often not the one that failed.
Validate scratch-definition changes with a deploy to a freshly created org.

## Evidence

`config/project-scratch-def.json:4` sets the language; the object definitions no longer carry `<gender>`. A fresh org from this definition accepts `apex-job/src` (154 components).
