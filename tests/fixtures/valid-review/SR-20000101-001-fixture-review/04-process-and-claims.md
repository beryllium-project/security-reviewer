<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Process, publication gate, and claim-boundary honesty

Package ID: `SR-20000101-001-fixture-review`
Title: Synthetic static-only review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

## Claim discipline

One claim exceeds its evidence (FINDING-001). Compare every documented claim of the target against the
evidence that supports it, and record where claims exceed, match, or
understate the evidence.

## Independence of this review

This package read only the target at the recorded commit, the shared
`contracts/` files, and public sources recorded in `search-log.md`.

## Publication and release gate

Not yet reviewed.

## Evaluator, build, and supply chain

Not yet reviewed.

## Engineering process

Not yet reviewed.

## Assurance wording

Beryllium is accepted through R7; Beryllium R8-H0 is a committed candidate and
is not accepted; H1-H4 are not authorized; K3 hardware is `NOT RUN`. Helium is
a review-and-test proof of concept and is not formally verified or hardware
validated; selected Helium C properties may be described as machine-checked by
CBMC only within their stated source, property, and tool boundary. A validated
candidate, approved predecessor, or inherited gate never approves a successor.
The agent never grants or infers implementation authorization, acceptance,
review approval, risk acceptance, sign-off, licensing, publication, release,
formal verification, or hardware validation.
