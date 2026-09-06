<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Evidence ledger

Package ID: `SR-20000101-001-fixture-review`
Title: Synthetic static-only review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

Evidence IDs (`SR-20000101-001-fixture-review-E####`) are append-only and unique within the
package. A correction adds a new row and names the corrected row in its
statement; rows are never rewritten or renumbered. Kind is one of
`Local file`, `Command output`, `Public source`, `User statement`, or
`Specialist return`. Fact label is `Established`, `Inferred`, `Proposed`, or
`Unknown`.

| Evidence ID | Source | Locator | Revision | Kind | Statement | Fact label | Recorded |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SR-20000101-001-fixture-review-E0001 | Fixture design note | `component://helium-te-poc/docs/fixture-design.md` | `1111111111111111111111111111111111111111` | Local file | The design places the fixture secret behind a request mediator that validates identifiers against an allowlist. | Established | 2000-01-01 |
| SR-20000101-001-fixture-review-E0002 | Fixture security note | `component://helium-te-poc/docs/fixture-security.md` | `1111111111111111111111111111111111111111` | Local file | The security note claims complete mediation but cites no test that exercises alias identifiers. | Established | 2000-01-01 |
