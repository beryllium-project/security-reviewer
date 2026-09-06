<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Disposition ledger

Package ID: `SRS-20000101-001-fixture-synthesis`
Title: Synthetic synthesis fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

One row per source finding from every input package; no source finding is
dropped. Disposition is `Confirmed`, `Partially confirmed`, `Recommendation`,
`Already addressed`, `Rejected-unsupported`, or `Fixed-scope non-goal`.
Canonical action is a `REV-P{0..3}-NN` ID defined in `synthesis.md`, or
`None`.

| Source finding | Package | Disposition | Canonical action | Rationale |
| --- | --- | --- | --- | --- |
| FINDING-001 | SR-20000101-001-fixture-review | `Confirmed` | REV-P2-01 | Current target evidence at `1111111111111111111111111111111111111111` still lacks an alias-identifier test (SRS-20000101-001-fixture-synthesis-E0001). |
