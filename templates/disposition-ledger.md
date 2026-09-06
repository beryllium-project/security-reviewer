<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Disposition ledger

Package ID: `@@PACKAGE_ID@@`
Title: @@TITLE@@
Created: @@CREATED@@
Status: `Draft`
Distribution: `private`

One row per source finding from every input package; no source finding is
dropped. Disposition is `Confirmed`, `Partially confirmed`, `Recommendation`,
`Already addressed`, `Rejected-unsupported`, or `Fixed-scope non-goal`.
Canonical action is a `REV-P{0..3}-NN` ID defined in `synthesis.md`, or
`None`.

| Source finding | Package | Disposition | Canonical action | Rationale |
| --- | --- | --- | --- | --- |
| None | Not recorded | Not recorded | None | No source finding has been dispositioned. |
