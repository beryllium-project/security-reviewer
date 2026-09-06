<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Scratch workspace

Disposable working files for in-progress evidence handling may be placed
here. All contents other than this policy file are ignored by Git (see
`.gitignore`); nothing here is tracked or backed up.

Scratch contents must never be the sole durable locator for a cited evidence
record. Anything that must survive the session belongs in the package under
`reviews/` or `syntheses/`. Retained command output belongs only in a
package's `evidence/APPROVAL-NNN/` directory, written by
`scripts/run-approved-command.sh`, never here.

Never copy material from
`component://osr-claude/sources/restricted-microsoft/` or any other
restricted source here.
