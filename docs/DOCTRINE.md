# Doctrine

Reusable judgment distilled from rulings: when a trade-off recurs, the entry says which way it goes.

## D-1 — Keep logic out of triggers

- **Trigger:** a design needs to set or derive a JobRequest__c or JobDescription__c value at save time.
- **Rule:** use a declarative mechanism (field default, formula) before trigger code; a trigger only delegates to a service in one line, and only for side effects no declarative mechanism can express, such as the executor wake-up; a path the declarative mechanism misses that cannot be documented away needs its own ruling.
- **Evidence:** R-002.
- **Counter-cases:** none
