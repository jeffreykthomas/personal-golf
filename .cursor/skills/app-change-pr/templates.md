# Templates

## Subagent prompt skeleton

```text
Implement the requested app change in this repository.

User goal:
- <plain-English request>

Acceptance criteria:
- <criterion 1>
- <criterion 2>

Constraints:
- Do not revert unrelated local changes.
- Run the narrowest relevant verification.
- Report files changed, tests run, and any open risks.

Relevant files to inspect first:
- <file 1>
- <file 2>
```

## Branch name examples

```text
agent/fix-tip-validation
agent/add-round-summary-ui
agent/improve-onboarding-copy
```

## PR body template

```markdown
## Summary
- <user-facing change>
- <important implementation note>

## Test plan
- [x] <targeted check that was run>
- [ ] <manual or follow-up check, if still needed>
```

## Decision rule

Use a subagent when:
- the task spans multiple files
- you need parallel research or implementation
- the request is clear enough to delegate cleanly

Stay here when:
- the change is small and localized
- the main work is git, PR, or final review
- the risk is mostly about preserving surrounding local changes
