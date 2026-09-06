<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Evidence ledger

Package ID: `SR-20000101-002-fixture-executed`
Title: Synthetic execution-backed review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

Evidence IDs (`SR-20000101-002-fixture-executed-E####`) are append-only and unique within the
package. A correction adds a new row and names the corrected row in its
statement; rows are never rewritten or renumbered. Kind is one of
`Local file`, `Command output`, `Public source`, `User statement`, or
`Specialist return`. Fact label is `Established`, `Inferred`, `Proposed`, or
`Unknown`.

| Evidence ID | Source | Locator | Revision | Kind | Statement | Fact label | Recorded |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SR-20000101-002-fixture-executed-E0001 | Fixture design note | `component://helium-te-poc/docs/fixture-design.md` | `2222222222222222222222222222222222222222` | Local file | The design places the fixture secret behind a request mediator. | Established | 2000-01-01 |
| SR-20000101-002-fixture-executed-E0002 | APPROVAL-001 stdout | `evidence/APPROVAL-001/stdout.log` | `2222222222222222222222222222222222222222` | Command output | The approved command exited 0 and printed the single line `fixture`. | Established | 2000-01-01 |
