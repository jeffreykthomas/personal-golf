---
name: app-change-pr
description: Use this when a user asks for a feature, bug fix, UX change, workflow change, or behavior change that may require updating this app. Treat product or UI requests like developer work: turn them into code changes, validate them, and, when requested, create a branch, commit, push, and open a GitHub pull request.
---

# App Change PR Workflow

Use this workflow when the request is really a product or app change, even if it is described in end-user terms.

## Core rule

Treat the human like a developer stakeholder:
- Do not require implementation-language requests.
- Infer the likely app change from the user-facing problem.
- Keep the user in the approval loop with a branch and PR when shipping code is requested.

## When to use

Use this workflow for:
- feature requests
- bug fixes
- UX or copy changes
- workflow changes driven by user behavior
- requests that imply "update the app to support this"

Do not use this workflow for:
- pure explanation or research requests
- one-off local experiments the user does not want committed
- changes that should stay as notes, plans, or docs only

## Workflow

1. Clarify acceptance criteria only if they are genuinely ambiguous.
2. Check the repo state before coding:
   - `git status --short`
   - note unrelated local changes and work around them
   - do not revert user changes
3. If the task is large or architectural, switch to Plan mode first.
4. For implementation work, choose one of these paths:
   - implement directly for small, clear changes
   - use a `generalPurpose` subagent for multi-file or exploratory coding work
5. Validate with the narrowest useful checks first.
6. If shipping is part of the request, finish with branch, commit, push, and PR creation.

## Subagent pattern

When you spawn a coding subagent:
- give it the user goal, acceptance criteria, and relevant files
- tell it to make the code changes and run targeted verification
- keep final git branching, commit, push, and PR creation here
- review the result before presenting it as complete

For wording and templates, see [templates.md](templates.md).

## Validation defaults for this repo

This is a Rails app. Prefer:
- targeted model/controller tests with `bin/rails test <path>`
- `bin/rails test` for broader backend changes
- `bin/rails test:system` only when the change materially affects UI flows

If a different project-specific check is more appropriate, run that instead.

## Branch and PR policy

If the request is implementation only, stop after code changes and verification.

If the request includes shipping the change, or clearly asks for a PR:
- create a task branch
- commit only relevant files
- push to `origin`
- open a PR with a concise summary and test plan

Never:
- commit unrelated dirty-worktree files
- push to `main` directly
- force-push unless the user explicitly asks

## Practical defaults

- Branch name: `agent/<short-slug>`
- Keep commits focused on one user request
- Prefer a small, reviewable PR over a broad refactor
- If verification is limited, say exactly what was and was not checked

## Completion

At the end, report:
- what changed
- what you verified
- the branch name
- the PR URL, if one was created
