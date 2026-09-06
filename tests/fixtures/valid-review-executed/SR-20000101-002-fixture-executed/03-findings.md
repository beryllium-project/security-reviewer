<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Findings

Package ID: `SR-20000101-002-fixture-executed`
Title: Synthetic execution-backed review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

Severity is rated against the target's own stated scope and claim boundary,
not against an idealized system. Every finding cites at least one evidence ID
defined in `evidence-ledger.md` and names the affected paths at the exact
reviewed commit. Findings are never renumbered.

<!--
Record format (one H3 per finding; exactly these bullet keys in this order):

### FINDING-001: <title>

- Severity: `High`
- Confidence: `Medium`
- Fact label: `Established`
- Affected paths: `component://<name>/<path>` at `<40hex>`
- Evidence: `SR-YYYYMMDD-NNN-E0001`, `SR-YYYYMMDD-NNN-E0002`
- Impact: <text>
- Recommendation: <text>
- Alternatives and counter-evidence: <text or `None identified`>
- Limitations: <text>

Severity: Critical | High | Medium | Low | Informational.
Confidence: High | Medium | Low.
Fact label: Established | Inferred | Proposed | Unknown.
Affected paths: one or more comma-separated, or `None`.
Evidence: one or more evidence IDs; never empty.
Replace the line "No findings recorded." with the first record.
-->

## Summary

| Finding | Severity | Confidence | Title |
| --- | --- | --- | --- |
| FINDING-001 | `Informational` | `High` | Fixture self-test output is not compared against an expected value |

## Findings

### FINDING-001: Fixture self-test output is not compared against an expected value

- Severity: `Informational`
- Confidence: `High`
- Fact label: `Established`
- Affected paths: `component://helium-te-poc/docs/fixture-design.md` at `2222222222222222222222222222222222222222`
- Evidence: `SR-20000101-002-fixture-executed-E0001`, `SR-20000101-002-fixture-executed-E0002`
- Impact: The self-test demonstrates execution but not correctness; a regression in the mediator would not change the output.
- Recommendation: Compare the self-test output against a recorded expected value.
- Alternatives and counter-evidence: None identified.
- Limitations: Synthetic fixture; one approved command was run.
