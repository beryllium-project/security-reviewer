<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Evidence ledger

Package ID: `SRS-20000101-001-fixture-synthesis`
Title: Synthetic synthesis fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

Evidence IDs (`SRS-20000101-001-fixture-synthesis-E####`) are append-only and unique within the
package. A correction adds a new row and names the corrected row in its
statement; rows are never rewritten or renumbered. Kind is one of
`Local file`, `Command output`, `Public source`, `User statement`, or
`Specialist return`. Fact label is `Established`, `Inferred`, `Proposed`, or
`Unknown`.

| Evidence ID | Source | Locator | Revision | Kind | Statement | Fact label | Recorded |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SRS-20000101-001-fixture-synthesis-E0001 | Input package finding | `tests/fixtures/valid-review/SR-20000101-001-fixture-review/03-findings.md` | `1111111111111111111111111111111111111111` | Local file | FINDING-001 of the input package cites SR-20000101-001-fixture-review-E0002 and remains unaddressed at the recorded commit. | Established | 2000-01-01 |
