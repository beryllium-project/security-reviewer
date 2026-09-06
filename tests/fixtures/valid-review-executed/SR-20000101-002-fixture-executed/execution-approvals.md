<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Execution approvals

Package ID: `SR-20000101-002-fixture-executed`
Title: Synthetic execution-backed review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

Target execution is prohibited unless the responsible human approves each
command by exact text in the session. Every approved command is one
`APPROVAL-NNN` record below; `scripts/run-approved-command.sh` refuses any
command without a matching `approved` record, and the validator cross-checks
every `executed` record against `review-manifest.json`. An approval record is
an attestation: the validator checks consistency, not truth.

<!--
Record format (copy exactly; one record per approved command; never renumber):

### APPROVAL-001

- Status: `approved`
- Command: `./he test`
- Working directory: `component://helium-te-poc`
- Tool ID: `he`
- Tool version: `unknown`
- Expected target commit: `<40 hex>`
- Approved by: responsible human
- Approved on: `2026-09-06T18:00:00Z`
- Quoted approval: "<exact user words from the session>"
- Evidence directory: `evidence/APPROVAL-001/`

Status is `approved` (not yet run), `executed` (evidence retained and listed in
the manifest), or `withdrawn`. A `Tool version` of `unknown` requires a
manifest qualification. Commands must not contain backticks. Replace the line
"No approvals recorded." with the first record.
-->

### APPROVAL-001

- Status: `executed`
- Command: `printf 'fixture\n'`
- Working directory: `component://helium-te-poc`
- Tool ID: `printf`
- Tool version: `coreutils-fixture`
- Expected target commit: `2222222222222222222222222222222222222222`
- Approved by: responsible human
- Approved on: `2000-01-01T00:00:00Z`
- Quoted approval: "You may run printf 'fixture\n' in helium-te-poc for this fixture."
- Evidence directory: `evidence/APPROVAL-001/`
