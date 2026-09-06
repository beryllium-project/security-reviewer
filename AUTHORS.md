<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-reviewer authorship and responsibility

James Morris `<jamorris@linux.microsoft.com>` is the responsible human author,
reviewer, copyright holder, and publication authority for this component.
His alternate email address is `<jmorris@namei.org>`.

This component has been developed with GitHub Copilot CLI. Its maintained
tooling is dependency-free Bash and Node.js; it has no build step.

## Derivation record

The review contract in `contracts/`, the manifest linter
`scripts/lint-review-manifest.mjs`, and its test suite
`tests/test-review-manifest.mjs` were extracted from the Helium proof of
concept and generalized for Beryllium-wide use:

| Origin | Extracted at |
| --- | --- |
| `component://helium-te-poc/agent-review/REVIEW-PROMPT.md` | commit `9b3ff4e9441e5b4434a8ec37794dee1d941e11ef`, branch `helium-te-travel-fedora44` |
| `component://helium-te-poc/agent-review/REVIEW-PROVENANCE.md` | same |
| `component://helium-te-poc/agent-review/review-manifest.schema.json` | same |
| `component://helium-te-poc/agent-review/review-manifest.template.json` | same |
| `component://helium-te-poc/tests/lint-review-manifest.mjs` | same |
| `component://helium-te-poc/tests/test-review-manifest.mjs` | same |
| `component://helium-te-poc/docs/review-remediation.md` (method and disposition vocabulary only) | same |

The process discipline (guided intake, exact-revision freeze, evidence
ledger, private-by-default packages, human promotion records) follows the
sibling `threat-modeler` component. Helium's retained review packages under
`component://helium-te-poc/agent-review/<package>/` are historical inputs
referenced read-only; they were not copied, and nothing in Helium was
changed by this extraction. Helium remains licensed `GPL-3.0-only`, and this
component keeps the same license (`LICENSES/GPL-3.0-only`).

AI assistance does not transfer human responsibility:

- AI tools do not certify the Developer Certificate of Origin.
- AI tools do not add a human `Signed-off-by`.
- AI tools do not approve publication, release, or any review outcome.
- AI tools are not represented as human co-developers or copyright holders.
- The responsible human reviews correctness, provenance, licensing,
  documentation, and every security-review claim before any use.
