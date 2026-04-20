# Contributing to Async Processor

Thank you for considering a contribution! This project follows clean code, SOLID, and strong testing principles tailored for Salesforce Apex development.

## Ground Rules
- Keep methods/classes short, focused, and with clear intent.
- Prefer expressive names over comments. Comments only for tricky algorithms.
- Adhere to SRP, DRY, YAGNI, KISS, and clear separation of concerns.

## Development Setup
1. Prerequisites
   - Node.js 22+
   - npm 10+
   - Salesforce CLI (installed automatically via postinstall): `@salesforce/cli`
2. Install dependencies
   - `npm install`
3. Create or select a dev org
   - Scratch org (example):
     - `sf org create scratch -f config/project-scratch-def.json -a dev -d 1`
     - `sf org open -o dev`
4. Deploy
   - `npm run build` (deploys `apex-job/` to the default org)

## Useful Scripts
- Format & Lint: `npm run prettier` then `npm run lint` (also runs as part of build).
- Build/Deploy: `npm run build`.
- Unit tests: `npm run test:unit`.
- Integration tests: `npm run test:integration`.
- Full test workflow: `npm test`.
- Functional tests (optional):
  - `npm run test:functional:prepare-metadata`
  - `npm run test:functional:load-data`
  - `npm run test:functional:start` / `npm run test:functional:stop`
- Anonymous-Apex operator scripts under `scripts/apex/`:
  - `scripts/apex/restart-watcher.apex` — aborts every existing `Async Job Watcher` cron trigger and calls `ApexJobWatcher.schedule()` to re-register them. Run: `sf apex run -f scripts/apex/restart-watcher.apex -o <org-alias>`.
  - `scripts/` is outside every `sfdx-project.json` packageDirectory, so it never deploys to orgs.

### Pre-commit hook
Husky's `pre-commit` runs `lint-staged`, which invokes `sf code-analyzer run -t <staged .cls/.xml files>` directly (not through `npm run lint`). The direct-CLI path preserves argument quoting for filenames that contain spaces — e.g. the `JobDescription__c-Job Description Layout.layout-meta.xml` layout file would otherwise be split on whitespace by wireit's argument forwarder.

## Code Style
- Formatting: Prettier with `prettier-plugin-apex`
- Static analysis: `sf code-analyzer run` with `apex-ruleset.xml`
- Use `final` for variables and parameters when possible.

## Testing Guidelines
- Structure: 3A (Arrange, Act, Assert) and Given-When-Then method names.
- Use Apex Mockery correctly:
  - Create with `Mock.forType()`, use `.stub` for injection.
  - Stub via `mockInstance.spyOn('method').returns(value)`.
  - Verify via `Expect.that(spy).hasBeenCalled()` or `.hasBeenCalledWith(...)`.
- The system under test variable is named `sut`.
  - **Exception — stateless static utilities** (`ConsumptionModel.asList()`, `TestDataFactory.generateUniqueFakeId(...)`, constants classes): there is no instance to assign to `sut`. Name tests for the *operation under test* and keep the call inline in the Act section. Do not invent a dummy variable just to satisfy the rule.
- **Prefer minimum-contract assertions over exact-set assertions.** When the shape being asserted grows over time (enum values, field lists, dimensions registered in `ConsumptionModel.asList()`, picklist entries), write the assertion as *"must contain X and Y"* rather than *"must equal exactly {X, Y}"*. Exact-set assertions force an unrelated test update every time the shape legitimately grows, which trains contributors to tweak assertions without thinking — and a brittle assertion that passes is indistinguishable from a correct one.
  - Red flags: `Assert.areEqual(5, enum.values().size())`, `Assert.areEqual(expectedFieldSet, actualFieldSet)` where the field set is a moving contract, `Set<...> expected = new Set<...>{ ... }; Assert.areEqual(expected, actual);`.
  - Prefer: iterate the contract (`for (ConsumptionModel m : ConsumptionModel.asList()) Assert.isTrue(actual.contains(m.base), ...)`), assert `containsAll(mustHave)` against an expected subset, or split into one test per invariant that can evolve independently.
  - If you *must* assert the exact shape (e.g. proving nothing leaked beyond the contract), pair it with a comment explaining the invariant and link the failure message to the file that needs the matching update.
- Cover edge cases, governor limits behavior, and permissions. Aim for 100% coverage with util tests.
- Use `ApexJobTestFixture` and `ApexJobTestMock` in to configure tests.

## Architecture Notes
- Limits calculations live in `LimitServiceImpl` and are mapped onto the simple DTO `LimitsUsage`.
- Job filtering is performed in `JobSelectorImpl` using available limits and buffer handling.
- Keep business logic separated from data manipulation; prefer small, cohesive classes.

## Adding a New Governor Limit Dimension

When adding a new governor limit dimension (e.g., `newDimension`), the following files require changes. Domain consumers like `AdaptiveChunkCalculator`, `AdaptiveConsumptionLearner`, and `ApexJobManager.resetConsumptionModel()` iterate over `ConsumptionModel.asList()` and require **zero changes**.

1. **`JobDescription__c`** — Create 3 custom fields:
   - `NewDimensionBaseConsumption__c` (Number)
   - `NewDimensionPerItemConsumption__c` (Number)
   - `NewDimensionSafety__c` (Number)

2. **`LimitsUsage.cls`** — 3 additions:
   - [ ] Add `private static final String NEW_DIMENSION_DIMENSION = 'newDimension';`
   - [ ] Add to `ALL_DIMENSIONS` list
   - [ ] Add property with get/set wrapping the map store

3. **`LimitServiceImpl.cls`** — 3 additions:
   - [ ] Add line in `getConsumedLimits()` using `Limits.getNewDimension()`
   - [ ] Add line in `stopSnapshot()` computing consumed delta
   - [ ] Add line in `getAvailableLimits()` computing `Limits.getLimitNewDimension() - Limits.getNewDimension()`

4. **`JobSelectorImpl.cls`** — 4 additions:
   - [ ] Add 3 fields to SELECT: `JobDescription__r.NewDimensionBaseConsumption__c`, `...PerItemConsumption__c`, `...Safety__c`
   - [ ] Add 1 WHERE condition: `AND JobDescription__r.NewDimensionBaseConsumption__c <= :availableLimits.newDimension`

5. **Test fixtures** — `ApexJobTestFixture.cls`:
   - [ ] Add `withNewDimensionConsumption`, `withNewDimensionPerItemConsumption`, `withNewDimensionSafety` builder methods in `JobDescriptionBuilder`
   - [ ] Add `this.usage.newDimension = 0;` in `LimitsUsageBuilder` constructor
   - [ ] Add `withNewDimension` builder method in `LimitsUsageBuilder`
   - [ ] Add `.withNewDimension(Limits.getLimitNewDimension())` in `createMaxAvailableLimits()`

6. **Tests** — Verify:
   - [ ] `LimitServiceImplTest` — snapshot and available limits include the new dimension
   - [ ] `JobSelectorImplTest` — filtering by the new dimension works
   - [ ] `AdaptiveChunkCalculatorTest` — chunk calculation considers the new dimension (automatic via `ConsumptionModel.asList()`)

## Design and implementation plan docs

Non-trivial features land with a pair of Markdown docs under:

- `docs/design/YYYY-MM-DD-<slug>.md` — the **why**: problem statement, behaviour,
  data model, algorithm, touchpoint summary, edge cases, rollback.
- `docs/plan/YYYY-MM-DD-<slug>.md` — the **how**: meta header, branch name,
  PR description template, numbered `### Task N:` blocks with file inventory,
  exact code/XML snippets, and conventional-commit messages.

Precedents to mirror: the rate-limiting pair (`docs/plans/2026-03-03-rate-limiting-design.md`
+ `docs/plans/2026-03-03-rate-limiting.md`, legacy single-folder layout) and the
2026-04-19 deep-review batch (16 pairs under `docs/design/` + `docs/plan/`).

Each task in a plan doc should always end with a `git add` + `git commit -m "…"`
block so the plan reads as an executable script. Target `SF_TARGET_ORG=dev-async-processor`
(or the alias your scratch org uses) for all `sf` commands referenced in the plan.

## Commit, Branch, PR
- Branch from `main`: `feature/<short-description>` or `fix/<short-description>`.
- Write concise commits (imperative mood). Example: `feat(selector): filter jobs by available CPU with buffer`. Respect conventional-commits (`feat|fix|refactor|chore|docs|test|perf|ci(scope?): subject`).
- PR Checklist:
  - [ ] Code formatted and linted
  - [ ] Unit/integration tests added/updated and passing
  - [ ] Follows SOLID and clean code rules (good craftsmanship)
  - [ ] README/Docs updated if needed (including the paired `docs/design/` + `docs/plan/` entries for new features)

## Reporting Issues
Open an issue with a minimal reproduction, expected vs actual, logs, and environment details.
