# Native Git Issues - Expert Panel Review & Analysis

**Date**: 2025-04-23
**Author**: Emerson Soares (remenoscodes@gmail.com)
**Reviewed by**: Technical Architecture Expert, Linus Torvalds (persona), Junio C Hamano/Gitster (persona)

---

## Author's Motivation & Linus's Own Words

This proposal was directly inspired by Linus Torvalds's own statements about bug tracking being an unsolved problem. In a 2007 mailing list discussion ([yarchive.net/comp/linux/bug_tracking.html](https://yarchive.net/comp/linux/bug_tracking.html)), Linus wrote:

> "There must be some better form of bug tracking than bugzilla. Some really
> distributed way of letting people work together, *without* having to
> congregate on some central web-site kind of thing. **A 'git for bugs', where
> you can track bugs locally and without a web interface.**"

> "And I think it would be something much closer to '**distributed email mbox
> with status tracking facilities**', *not* a web clicky interface."

> "The thing is, bugzilla is totally broken because it's designed to help
> track bugs, but it's *not* designed to actually handle the much harder
> problem, which is to actually **get the *right* developers to be aware of
> the *right* bugs!**"

**The vision**: Imagine doing `git clone` and checking out not just your codebase, but the full history of issues — which ones were solved, which are open, linked to the exact commits that fixed them. Imagine contributing to issues the same way you contribute code. Imagine migrating from GitHub to GitLab and your entire issue history travels with the repository, as naturally as your branches and tags do.

This is not about building a project management suite inside Git. It's about treating issue metadata as first-class data that deserves the same distributed, decentralized, content-addressed properties that Git gives to source code. Linus asked for exactly this. No one has delivered it *inside Git itself* yet.

---

## Executive Summary

Three independent reviewers assessed the Native Git Issues proposal: a distributed systems architect, and two persona agents channeling Linus Torvalds and Junio C Hamano (Gitster). The consensus is:

**The concept has merit. The implementation needs fundamental redesign before proceeding.**

### Verdict: CONDITIONAL GO

The idea of storing issues in Git's object model is valid and has precedent (git-bug, Fossil). However, the current MVP has critical architectural flaws that must be resolved before submitting to the mailing list. The path forward is clear but requires significant rework.

---

## Review 1: Technical Architecture Expert

### Score: 3.7/10

### Key Findings

| Dimension | Rating | Critical Issue |
|---|---|---|
| Data Model | 6/10 | Trailer parsing fragile, no schema versioning |
| Ref Namespace | 4/10 | `next-id` as plain file is fundamentally broken |
| ID Allocation | 2/10 | Sequential IDs cannot work distributed |
| Scalability | 3/10 | Shell per-issue subprocess spawning won't scale |
| Merge Strategy | 3/10 | Described but unimplemented; label removal unsolvable with set-union |
| Bridge Protocol | 5/10 | JSON injection, no pagination, no incremental sync |
| Code Quality | 5/10 | Functional but has hardcoded paths, race conditions, injection vectors |
| Prior Art Delta | 3/10 | git-bug already solved most problems; unclear what this adds |
| Core Feasibility | 2/10 | Significant redesign needed |

### Critical Bugs Found
1. `git-issue-create` hardcodes `.git/` path (breaks worktrees, bare repos, submodules)
2. `git-issue-ls` `get_issue_title()` reads ALL commits without `-1` limit
3. `git-issue-comment` pipes message via `echo` (breaks on messages starting with `-`)
4. Trailer injection: newlines in title inject arbitrary trailers
5. JSON injection in bridge: unescaped user content in string-concatenated JSON
6. TOCTOU race condition on `next-id` counter

---

## Review 2: Linus Torvalds (Persona)

### Verdict: NAK on builtin. Soft NAK on contrib as-is. Recommend standalone project.

### Key Positions

**"Git is a content tracker. Not a project management suite."**
- Every time someone proposes "Git should also do X," the answer is: X should be a separate tool that uses Git
- Issues are fundamental to development, but so is email, so is lunch -- doesn't mean Git should handle them

**"You've built a key-value database on top of commit messages."**
- Commits with empty trees containing only metadata is a creative abuse of the object model
- But at that point, why not use an actual database?
- The commit object was designed for state transitions of a tree

**Performance critique:**
- `git-issue-ls` does 4 subprocess invocations per issue = 4,000+ process spawns for 1,000 issues
- "You're building an O(n*k) algorithm where n is issues and k is metadata fields, using process forking as your inner loop"
- Even in C, the fundamental data model is wrong for random-access queries with filtering

**Distributed ID problem:**
- "Your `refs/issues/next-id` file... is the kind of thing that WILL break when someone uses a reftable backend"
- Two developers creating issues offline will collide

**Bridge protocol:**
- "Half your patch series is a synchronization engine for GitHub Issues. Do you realize what you're signing up for?"
- Bidirectional sync of mutable state is one of the hardest problems in CS
- The `# TODO: Implement proper merging` comment "is doing a LOT of heavy lifting"

**Recommended alternative:**
1. Define a standard exchange format for issues
2. Build a standalone tool that snapshots issues into a Git repo
3. Make bridges plugins to that tool, not to Git
4. Don't touch `refs/issues/`, don't add commands to the `git` namespace

---

## Review 3: Junio C Hamano / Gitster (Persona)

### Verdict: Interesting direction, but fundamental issues must be resolved before proceeding. Looking forward to v2.

### Key Positions

**Cover letter quality:**
- Well-structured, but diffstat shows placeholder ("Your Name (N):") instead of real values
- Round line counts suggest approximations rather than actual `git format-patch` output

**`next-id` is the single most serious issue:**
- Not a proper ref -- invisible to push/fetch, breaks reftable, breaks mirror
- Suggests alternatives: blob in a proper ref (`refs/issues/meta`) or derive from existing refs

**Trailer format is non-standard:**
- Current format puts "trailers" BEFORE the body -- opposite of Git convention
- `git interpret-trailers` won't work with current format
- Should restructure to use proper trailers at the end, use `git interpret-trailers` for both creation and parsing

**Shell portability:**
- `local` keyword is not POSIX (used extensively in `git-issue-ls` and `git-issues-sync`)
- Inconsistent `[ ]` vs `test` usage
- Missing `--` end-of-options handling
- `echo` may mangle backslashes on some platforms

**Test quality issues:**
- `cd test-repo` inside `test_expect_success` is fragile and violates conventions
- Missing `&&`-chaining in bridge tests (failures would be masked)
- No negative tests (error cases)
- No concurrency tests
- `test-native-issues.sh` in repo root should be removed (duplicates `t/9000`)

**Bridge maintenance burden:**
- `jq` is not a Git dependency -- significant to add
- Who maintains the GitHub bridge when their API changes?
- JSON injection vulnerability in `cmd_put`

**`git notes` relationship:**
- Proposal doesn't mention `git notes` at all
- Relationship should be discussed since notes already attach metadata to objects

**Incremental path critique:**
- Jumps from "gather feedback" to "move to builtin" -- needs intermediate milestones
- Gap between shell scripts and C builtins is large

---

## Consolidated Critical Issues

### Must Fix (Blockers)

| # | Issue | Raised By | Severity |
|---|---|---|---|
| 1 | **Sequential IDs don't work distributed** | All three | Architecture |
| 2 | **`next-id` is a plain file, not a ref** | All three | Architecture |
| 3 | **Trailer format is non-standard** (before body, not after) | Gitster, Architect | Architecture |
| 4 | **JSON injection in bridge** | All three | Security |
| 5 | **Trailer injection via newlines** | Architect | Security |
| 6 | **Hardcoded `.git/` path** | Architect, Gitster | Compatibility |
| 7 | **`local` keyword is non-POSIX** | Gitster | Portability |
| 8 | **No merge driver implementation** | All three | Completeness |

### Should Fix (Important)

| # | Issue | Raised By |
|---|---|---|
| 9 | No schema versioning | Architect |
| 10 | Tests lack `&&`-chaining | Gitster |
| 11 | No error case tests | Gitster |
| 12 | No concurrency tests | Gitster, Architect |
| 13 | Bridge lacks pagination | Architect |
| 14 | Bridge lacks incremental sync | Architect |
| 15 | Cover letter has placeholder diffstat | Gitster |
| 16 | No mention of `git notes` relationship | Gitster |
| 17 | `get_issue_state` only reads tip commit | Gitster, Architect |
| 18 | Performance at scale untested | All three |

---

## Analysis & Recommendation

### What the Reviewers Agree On

1. **The problem is real** -- vendor lock-in, offline access, portability of issues
2. **The concept of using Git objects** for issues is not crazy -- git-bug proves it works
3. **The current implementation has critical flaws** that prevent mailing list submission
4. **`contrib/` is the right starting place** (if it stays in the Git tree at all)

### Where They Disagree

- **Linus**: This should NOT be in Git at all -- build it as a standalone tool
- **Gitster**: This COULD be in Git, but needs much more work and proper maturation in contrib
- **Architect**: The concept is sound but should learn heavily from git-bug's 6+ years of iteration

### The "Why Not Just Use git-bug?" Question

This is the elephant in the room. `git-bug` already:
- Uses UUIDs (solves the ID problem)
- Uses OR-Set CRDTs (solves the merge problem)
- Has GitHub/GitLab/Jira bridges
- Has been in production since 2018

The proposal must answer: **what does native Git issues offer that git-bug doesn't?**

Possible answers:
- **Standardization**: A spec blessed by the Git project would enable ecosystem-wide adoption
- **Infrastructure reuse**: Leveraging `for-each-ref`, `interpret-trailers`, and Git's transport layer means less code
- **Lower barrier**: Being in `contrib/` or `builtin/` means availability without additional installation
- **Simpler data model**: git-bug's DAG-per-bug model is powerful but complex

---

## Continuity Plan

### Phase 0: Fundamental Redesign (Weeks 1-3)

**Priority 1 — Fix the data model:**

1. **Replace sequential IDs with UUIDs**
   - Use `uuidgen` or derive from root commit SHA
   - Refs become `refs/issues/<uuid-prefix>` (7-8 chars, like git-bug)
   - Optional local display mapping (sequential numbers for human readability)

2. **Fix the `next-id` mechanism**
   - If keeping display IDs: store counter as a blob in `refs/issues/meta`
   - If switching to UUIDs: derive display IDs from `for-each-ref` ordering

3. **Use proper Git trailers**
   - Restructure commit messages: subject line + body + trailers at end
   - Use `git interpret-trailers` for creation and parsing
   - Enables `%(trailers:key=State)` in `for-each-ref` format strings

4. **Add schema versioning**
   - `Format-Version: 1` trailer in root commits
   - Allows future evolution without breaking existing issues

**Priority 2 — Fix security:**

5. Validate all user inputs (reject newlines in trailer values)
6. Use `jq` for ALL JSON construction in bridge (no string concatenation)
7. Use `$(git rev-parse --git-dir)` instead of hardcoded `.git/`

**Priority 3 — Fix portability:**

8. Remove all `local` usage (or switch to `#!/bin/bash`)
9. Use `test` instead of `[ ]`
10. Handle `--` end-of-options in all argument parsers
11. Use `printf` instead of `echo` for commit messages

### Phase 1: Solid MVP (Weeks 4-6)

12. Implement basic merge driver (at least state and labels)
13. Add comprehensive tests:
    - Error cases (invalid IDs, missing issues, malformed input)
    - Concurrency (parallel `git issue-create`)
    - Scale test (create 500+ issues, measure `git issue-ls` time)
    - Proper `&&`-chaining throughout
14. Remove `test-native-issues.sh` from repo root
15. Fix `cd test-repo` pattern in tests
16. Add a README to `contrib/git-issue/`
17. Write man pages (even minimal ones)

### Phase 2: Address Linus's Concern (Weeks 7-8)

The strongest criticism is "why is this Git's problem?" To answer this:

18. **Document the case for standardization** — write a clear argument for why a Git-blessed issue format benefits the ecosystem more than another standalone tool
19. **Benchmark against git-bug** — show what the simpler data model gains (or costs)
20. **Define the issue exchange format** — even if the tools don't get into Git, a standard format could
21. **Consider the "standalone tool that uses Git plumbing" approach** — this may actually be the right first step before attempting `contrib/`

### Phase 3: Community Submission (Weeks 9-12)

22. Fix cover letter (real diffstat, real name, remove placeholder)
23. Address `git notes` relationship in documentation
24. Document edge cases (shallow clones, partial clones, worktrees, submodules)
25. Submit RFC v2 to `git@vger.kernel.org`
26. Prepare for 2-4 rounds of review

### Decision Gate

After Phase 2, make a go/no-go decision:

- **If the mailing list reception is positive** → Continue toward contrib inclusion
- **If Linus/Gitster push back hard on scope** → Pivot to standalone `git-issue` tool that is distributed independently (still uses Git plumbing, but doesn't live in the Git tree)
- **If git-bug adoption continues to grow** → Consider contributing to git-bug instead, or propose adopting git-bug's format as a standard

---

## Final Verdict

**The idea is NOT invalidated.** The concept of distributed, decentralized issue tracking using Git's object model is sound and validated by existing tools (git-bug, Fossil).

**The implementation needs a v2.** The current MVP proved the concept works mechanically but has architectural decisions (sequential IDs, non-standard trailers, plain-file counter) that are incompatible with Git's distributed model and conventions.

**The biggest strategic question** is not technical — it's political: should this live in the Git tree at all, or should it be a standalone tool? The answer depends on whether the Git community sees value in standardizing an issue format. That answer can only come from the mailing list.

**Recommended immediate action**: Fix the 8 blockers in Phase 0, then submit RFC v2 and let the community decide.
