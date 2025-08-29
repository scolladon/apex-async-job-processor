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
- Format & Lint: `npm run prettier` then `npm run lint` (also runs as part of build)
- Build/Deploy: `npm run build`
- Unit tests: `npm run test:unit`
- Integration tests: `npm run test:integration`
- Full test workflow: `npm test`
- Functional tests (optional):
  - `npm run test:functional:prepare-metadata`
  - `npm run test:functional:load-data`
  - `npm run test:functional:start` / `npm run test:functional:stop`

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
- Cover edge cases, governor limits behavior, and permissions. Aim for 100% coverage with util tests.
- Use `ApexJobTestFixture` and `ApexJobTestMock` in to configure tests.

## Architecture Notes
- Limits calculations live in `LimitServiceImpl` and are mapped onto the simple DTO `LimitsUsage`.
- Job filtering is performed in `JobSelectorImpl` using available limits and buffer handling.
- Keep business logic separated from data manipulation; prefer small, cohesive classes.

## Commit, Branch, PR
- Branch from `main`: `feature/<short-description>` or `fix/<short-description>`
- Write concise commits (imperative mood). Example: `feat(selector): filter jobs by available CPU with buffer`. (respect conventional commit)
- PR Checklist:
  - [ ] Code formatted and linted
  - [ ] Unit/integration tests added/updated and passing
  - [ ] Follows SOLID and clean code rules (good craftsmanship)
  - [ ] README/Docs updated if needed

## Reporting Issues
Open an issue with a minimal reproduction, expected vs actual, logs, and environment details.
