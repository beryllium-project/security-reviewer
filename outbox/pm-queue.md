<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Project Manager queue

This is a pull-only queue for the Beryllium Project Manager. The
security-reviewer appends `SRQ-NNN` rows with `Status` `new`. Rows are of
two kinds:

- `source`: a public source discovered during review work that is not
  already recorded by an owning Beryllium research component;
- `owner-action`: a synthesis canonical action (`REV-P{0..3}-NN`) recommended
  to a target owner.

Adding a row does not modify or notify another component. The Project Manager
owns every later status (`acknowledged`, `routed`, `integrated`, `declined`)
and edits only the `Status` and `Project Manager note` columns, as a carried
class-1 write. Target owners retain sole authority to accept, implement, or
decline an action; research owners retain sole authority to admit a source.
Never remove or renumber a row.

The queue is empty.

| ID | Kind | Recorded | Package | Summary | Recommended target | Status | Project Manager note |
| --- | --- | --- | --- | --- | --- | --- | --- |
