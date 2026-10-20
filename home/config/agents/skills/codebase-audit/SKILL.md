---
name: codebase-audit
description: Assess a codebase for dead or stale code, unnecessary complexity, unused flexibility, duplicated ownership, speculative edge handling, and cleanup decisions. Use for codebase health reviews, simplification assessments, and pre-cleanup audits. Produces evidence-backed findings without editing by default.
---

# Codebase audit

Ask of the code what a skeptical maintainer would: **What uses this? Why does it
exist? What real failure does it prevent? Could we remove it instead?**

Optimize for fewer maintenance obligations, not a finding quota or the largest
diff. Distinguish removable plumbing from complexity that protects implemented
behavior. A long function is a starting point for investigation, not a finding.

## Default contract

- Assess and report; do not edit, delete, install dependencies, create tasks, or
  commit unless requested. Ask before commands with meaningful external effects.
- Read repository instructions and relevant language/framework guidance first.
- Capture initial working-tree status. Recheck before reporting; user or parallel
  edits may invalidate findings. Never overwrite or claim those changes.
- Separate documented intent, actual implementation, fixture coverage, and live
  production evidence. None establishes the others automatically.

## 1. Map the system that actually runs

Read architecture contracts, package/build configuration, and entrypoints. Follow
imports and registration to identify:

- Production entrypoints, workers, commands, routes, jobs, and plugin hooks.
- Owners of canonical state, persistence, requests, identity, and presentation.
- Boundaries where external input is parsed and validated.
- Current capabilities versus roadmap prototypes and historical references.
- Tests, fixtures, compatibility constructors, generators, and development tools.

Trace representative use cases end to end. A function named `canonical`, a
comment saying "public API", or a comprehensive test suite does not prove that
production calls it. Conversely, entrypoint reachability alone does not prove a
particular branch can execute.

For large repositories, delegate disjoint areas in parallel: UI, engine/storage,
protocol/integrations, and tooling/tests. Require exact locations, caller evidence,
and a complete report. Independently verify the consequential findings.

## 2. Investigate candidates, not just patterns

Use path search to locate owners, symbol search to find callers, then read the
implementation and surrounding control flow. Inspect tests for the claimed
behavior. Avoid declaring code dead from a single unsuccessful search.

### What calls this?

- Does it have a production caller, only test callers, or no callers?
- Could configuration, dynamic imports, reflection, generated registration,
  package exports, or external consumers invoke it?
- Is a supposedly vendored implementation already gone, leaving empty folders?
- Does a generator have an output, build hook, or current consumer?
- Are historical names and comments describing an architecture that no longer exists?

Classify accurately: **unused**, **test-only**, **development-only**,
**future prototype**, and **public contract** are not interchangeable.

### Why does this interface offer more than its callers need?

Look for optional parameters never supplied, ignored return values, service
methods no workflow invokes, one-use pass-through wrappers, broad generic APIs
with one concrete use, and feature registries larger than the shipped surface.

Prefer removing the unused capability and its adapters/stubs over inventing a
new abstraction to maintain it. Do not force a cohesive domain method inline
merely because it is short.

### Why is this responsibility implemented twice?

Compare production and test assembly, old and new adapters, parallel request
handlers, caches, validation, retry policies, and resource ownership. Identify
actual behavioral differences, not just similar syntax.

Repeated validation at distinct external boundaries may be correct. A second
canonical store or an unused alternate orchestration path is a different issue.
Moving duplication into a generic helper is not automatically a simplification.

### Can this case happen at this point?

For each suspicious branch, establish the invariant immediately before it:

- Has an early return already ruled the case out?
- Is a captured primitive rechecked as though it could change?
- Is trusted domain data treated as unparsed external input?
- Does this support an obsolete caller or an unimplemented feature?
- Can state legitimately change across an await, callback, or lifecycle boundary?

Distinguish **impossible under a local invariant** from **rare but possible**.
Do not recommend dropping auth, account isolation, durability, cancellation,
reconnection, migration, or DOM lifecycle handling merely because it looks
unlikely. Explain the concrete failure, available evidence, likelihood, and cost.
If removal changes a product guarantee, present it as a decision requiring buy-in.

### Is optional fallback work happening unconditionally?

Look for eager parsing, full-page scans, serialization, copies, enrichment,
subscriptions, or network work before the primary path is tried. Check whether
collected diagnostic metadata is ever returned or observed. In reactive code,
check whether broad dependencies trigger work that only needs a few fields.

Recommend lazy work or narrower dependencies before deleting an unproven fallback.
Do not claim a performance improvement without measurement.

### Do tests exercise the implementation we ship?

- Do compatibility fixtures assemble a different runtime or scheduling path?
- Does a bounded-window fixture retain all entities, masking hydration/pruning errors?
- Are tests merely proving that a dormant registry agrees with another registry?
- Are meaningful parser/receipt assertions mixed with obsolete orchestration tests?

Preserve behavioral assertions. Prefer a small fixture using production assembly
over a parallel test framework. Test-only code can be necessary; tests for future
protocol behavior may be valuable evidence even when their orchestration is not.

## 3. Test each proposed simplification

For a finding worth reporting, establish:

1. **Evidence:** exact file/line, callers, control-flow invariant, and relevant tests.
2. **Consequence:** maintenance burden, duplicated authority, unnecessary work, or
   risk of testing behavior different from production.
3. **Smallest change:** what disappears, what remains, and what must change together.
4. **Confidence:** confirmed, conditional on a product/deployment decision, or
   investigation needed. Separate confidence from impact.
5. **Trade-off:** lost compatibility or useful evidence, changed guarantees, and
   the verification needed before removal.

Use history selectively to answer why code exists or what deployed versions need
support. Do not assume old migrations are obsolete or that "Git remembers it"
resolves current support obligations. Do not mistake source-line deletion for
bundle, runtime, or performance savings.

## 4. Verify within scope

Use existing static analysis and lightweight checks where practical. Follow the
repository's scan policy; read findings in context rather than treating every
match as a defect. Do not install a checker just to produce an unused-export list.

Ask before costly, destructive, credential-dependent, or live mutation tests.
Report what actually ran and distinguish fresh results from recorded evidence.
A passing lint/type check does not establish reachability or production safety.

## 5. Report for decisions, not theater

Lead with the highest-leverage conclusion, then group findings into:

- **Definite cleanup:** demonstrably unused code and invariant-proven redundancy.
- **Decisions needed:** dormant features, compatibility, roadmap scope, ownership.
- **Investigate first:** plausible simplifications without enough evidence yet.
- **Keep:** suspicious-looking complexity with concrete justification.

For each substantial finding, use a short question heading such as "Why do tests
assemble a different engine?" Follow with location, evidence, recommendation,
and caveat. Group tiny cleanups in a table instead of inflating their importance.
Do not pad the report with naming preferences or arbitrary function-length limits.

End with a small ordered cleanup plan, verification limits, and confirmation of
whether files changed. Scope estimates are approximate until a patch exists.
If no meaningful cleanup is justified, say so rather than manufacture findings.

**Guiding rule: remove unused capability and duplicated plumbing; preserve
complexity that protects an implemented behavior.**
