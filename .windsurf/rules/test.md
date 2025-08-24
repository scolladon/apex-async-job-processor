---
trigger: glob
globs: *Test.cls
---

## Testing Principles
3A (Arrange, Act, Assert): Structure unit tests with these three distinct sections.
Given When Then: Use this naming convention for test methods to clearly indicate the preconditions, actions, and expected outcomes. Ex private static void givenMethod_whenParameters_thenBehave()

## Mock
Use apex-mockery for mocking purpose (cf documentation https://github.com/salesforce/apex-mockery)

## Assertion
Uses Expect class to assert on MethodSpy
Else use Assert static methods (instead of deprecated System)
