<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Appendix: evidence map

Package ID: `SR-20000101-002-fixture-executed`
Title: Synthetic execution-backed review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

## Claim to evidence

| Target claim | Evidence IDs | Assessment |
| --- | --- | --- |
| None | None | Not yet reviewed. |

## Independent verification runs

| Approval | Command | Exit result | Evidence directory |
| --- | --- | --- | --- |
| APPROVAL-001 | `printf 'fixture\n'` | exited 0 | `evidence/APPROVAL-001/` |

## Finding to anchor

| Finding | Affected paths | Evidence IDs |
| --- | --- | --- |
| FINDING-001 | `component://helium-te-poc/docs/fixture-design.md` | SR-20000101-002-fixture-executed-E0001, SR-20000101-002-fixture-executed-E0002 |

## Explicitly not claimed by this review

- No formal verification, hardware validation, acceptance, or approval is
  claimed or implied.
