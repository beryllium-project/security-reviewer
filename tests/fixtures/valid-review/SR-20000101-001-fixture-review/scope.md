<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review scope

Package ID: `SR-20000101-001-fixture-review`
Title: Synthetic static-only review fixture
Created: 2000-01-01
Status: `Complete`
Phase: `Complete`
Mode: `independent-review`
Distribution: `private`
Execution: `static-only`
Latest review iteration: `REVIEW-ITERATION-001`

## Target snapshot

| Component | Logical locator | Commit | Branch | Worktree state | Included dirty paths | Checked |
| --- | --- | --- | --- | --- | --- | --- |
| helium-te-poc | `component://helium-te-poc` | `1111111111111111111111111111111111111111` | `refs/heads/helium-te-travel-fedora44` | clean | None | 2000-01-01 |

## Effective scope

- System or subsystem boundary: One synthetic monitor and one synthetic subject described by the fixture design notes.
- Included surfaces: The synthetic request path across one trust boundary.
- Exclusions: Availability, physical attacks, and everything outside the fixture design notes.
- Review depth: Focused.
- Public research: not permitted.
- Session execution set: None; no target command is approved.
- Intended distribution: private.
- Write boundary: This package and repository only; the target is never written.
- Known limitations: Synthetic fixture; no real target claim is established.

## Confirmation

- Discovery-mode choice: Independent review.
- Scope confirmation: Confirmed.
- Responsible human: Synthetic fixture actor.
- Confirmation date: 2000-01-01.

## Activity

| Activity ID | Date | Actor | Action | Evidence IDs | Notes |
| --- | --- | --- | --- | --- | --- |
| ACTIVITY-001 | 2000-01-01 | Security-reviewer | Allocated a private package. | None | Synthetic fixture. |
| ACTIVITY-002 | 2000-01-01 | Security-reviewer | Completed the static-only review. | SR-20000101-001-fixture-review-E0001, SR-20000101-001-fixture-review-E0002 | Synthetic fixture. |
