<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review scope

Package ID: `SR-20000101-002-fixture-executed`
Title: Synthetic execution-backed review fixture
Created: 2000-01-01
Status: `Complete`
Phase: `Complete`
Mode: `independent-review`
Distribution: `private`
Execution: `execution-backed`
Latest review iteration: `REVIEW-ITERATION-001`

## Target snapshot

| Component | Logical locator | Commit | Branch | Worktree state | Included dirty paths | Checked |
| --- | --- | --- | --- | --- | --- | --- |
| helium-te-poc | `component://helium-te-poc` | `2222222222222222222222222222222222222222` | `refs/heads/helium-te-travel-fedora44` | clean | None | 2000-01-01 |

## Effective scope

- System or subsystem boundary: One synthetic monitor and one synthetic subject described by the fixture design notes.
- Included surfaces: The synthetic request path and the fixture self-test command.
- Exclusions: Availability, physical attacks, and everything outside the fixture design notes.
- Review depth: Focused.
- Public research: not permitted.
- Session execution set: `printf 'fixture\n'` in `component://helium-te-poc` (APPROVAL-001).
- Intended distribution: private.
- Write boundary: This package and repository only; the target is never written.
- Known limitations: Synthetic fixture; the executed command only demonstrates the evidence path.

## Confirmation

- Discovery-mode choice: Independent review.
- Scope confirmation: Confirmed.
- Responsible human: Synthetic fixture actor.
- Confirmation date: 2000-01-01.

## Activity

| Activity ID | Date | Actor | Action | Evidence IDs | Notes |
| --- | --- | --- | --- | --- | --- |
| ACTIVITY-001 | 2000-01-01 | Security-reviewer | Allocated a private package. | None | Synthetic fixture. |
| ACTIVITY-002 | 2000-01-01 | Security-reviewer | Ran APPROVAL-001 and completed the review. | SR-20000101-002-fixture-executed-E0001, SR-20000101-002-fixture-executed-E0002 | Synthetic fixture. |
