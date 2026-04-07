# Native Git Issues v2 - Council Decisions & Revised Architecture

**Date**: 2025-04-23
**Author**: Emerson Soares (remenoscodes@gmail.com)
**Process**: 5-member deliberative council, each debating a critical design axis independently

---

## Origin

Linus Torvalds, 2007 ([yarchive.net](https://yarchive.net/comp/linux/bug_tracking.html)):

> "There must be some better form of bug tracking than bugzilla. Some really
> distributed way of letting people work together, *without* having to
> congregate on some central web-site kind of thing. **A 'git for bugs', where
> you can track bugs locally and without a web interface.**"

> "Something much closer to '**distributed email mbox with status tracking
> facilities**', *not* a web clicky interface."

---

## The 5 Council Decisions

### DECISION 1: Identity Model
**UUIDs with 7-character abbreviated display**

| Aspect | Choice |
|---|---|
| Canonical ID | UUIDv4 |
| Ref format | `refs/issues/<full-uuid>` |
| Display | 7-char prefix (expandable on collision, like Git SHAs) |
| Cross-references | `Fixes-Issue: <uuid-prefix>` in commit trailers |
| Sequential aliases | Deferred to v2 (if community demands it) |

**Rationale**: Distributed correctness is non-negotiable. UUIDs are the only option with zero collision across all clones with no coordination. Git developers already work with abbreviated hashes daily — `git issue-show a7f3b2c` extends Git's existing vocabulary naturally. Proven by git-bug (2018+).

**Rejected**: Sequential IDs (break distributed), SHA-based (two-step creation dance), per-clone display numbers (my #5 is your #7 — actively harmful), timestamp-based (clock skew, ugly).

---

### DECISION 2: Data Model
**Proper Git trailers with subject-line-as-title**

**Issue root commit format:**
```
Fix the login bug

The login page crashes when the user enters special characters
in the password field. Steps to reproduce:
1. Go to login page
2. Enter "pa$$w0rd" as password
3. Click submit

State: open
Labels: bug, auth
Assignee: dev@example.com
Code-SHA: abc123def456
Format-Version: 1
```

**State change commit:**
```
Close issue

State: closed
Fixed-By: abc123def456
Release: v2.1.0
```

**Comment commit:**
```
I can reproduce this on Firefox too

Tested on Firefox 120 and Chrome 119. Both crash with the same
error. The issue is in the password sanitizer.
```

**Comment + state change (combined):**
```
Fix deployed, closing

The fix in commit abc123 handles special characters properly.

State: closed
Fixed-By: abc123def456
```

| Design Rule | Choice | Why |
|---|---|---|
| Title | Subject line (1st line of commit) | Standard Git convention, `%(contents:subject)` works natively |
| Body | Commit body after blank line | Standard Git convention, `%(contents:body)` works |
| Metadata | Git trailers at END of message | `interpret-trailers` compatible, `%(trailers:key=State)` works |
| Schema | `Format-Version: 1` trailer | Enables future evolution |
| Custom fields | `X-FieldName: value` trailers | Email convention (X- prefix) |
| Provider mapping | `Provider-ID: github:42` trailer | Simple key-value |
| Binary attachments | Deferred to Format-Version 2 | Blobs in tree when needed |

**Key performance win**: `git issue-ls` becomes a single command:
```sh
git for-each-ref \
  --format='%(refname:short) %(contents:subject) %(trailers:key=State,valueonly)' \
  refs/issues/
```
Zero subprocess spawning. Works for 10,000+ issues.

**State computation rule**: The current state is the `State:` trailer value from the most recent commit that contains one:
```sh
git log --format='%(trailers:key=State,valueonly)' refs/issues/$ID | grep -m1 .
```

**Rejected**: Blobs in tree (loses `for-each-ref`/`interpret-trailers` integration), Git notes (mutable, not append-only), email headers at top (non-standard for Git, breaks all tooling), hybrid blob+trailers (two places to look = bug surface).

---

### DECISION 3: Project Scope & Home
**D+C Strategy: Start standalone, define format spec early, propose standardization once battle-tested**

#### Phase 1: Standalone Tool (Months 1-12)
- Name: `git-issue` (own repository)
- Language: Shell prototype, clear path to C rewrite
- Distribution: `brew install git-issue`, GitHub releases
- Ship: core commands + 1 bridge (GitHub) + standalone format spec document
- Validation: 3+ real projects using it, 1+ third-party implementation

#### Phase 2: Propose Format Standardization (Months 12-24)
- Submit the FORMAT SPEC (not the tool) to `git@vger.kernel.org`
- Framing: "Here is a format for `refs/issues/` with 1 year of production use. We ask you to bless the format, not merge our tool."
- This follows Git's precedent of documenting formats (`gitformat-pack`, `gitformat-index`)
- If blessed: GitHub/GitLab have a standard; `git-bug` can bridge to it
- If rejected: we still have a working tool, iterate and try again

**Why not stay in contrib/**: `git-subtree` has lived in contrib since 2012 and still hasn't graduated. The risk of multi-year limbo is too high. The real value is the FORMAT, not the tool placement.

**Why not pure standalone**: git-bug did this and after 7+ years still hasn't achieved ecosystem adoption. Missing piece: a format spec separate from the implementation.

**Why not contribute to git-bug**: Different design philosophy. git-bug uses CRDTs + Go-only. Our thesis is simpler data model + format standardization.

---

### DECISION 4: Merge Strategy
**Hybrid field-specific rules with three-way set merge for labels**

```
MERGE RULES FOR NATIVE GIT ISSUES:

1. COMMENTS
   Strategy: Union (append-only)
   Both sides' comments included, ordered by timestamp.
   Conflicts: Impossible.

2. STATE (open/closed)
   Strategy: LWW (latest commit timestamp wins)
   Ties: lexicographically greater SHA wins.
   Conflicts: Never — one side always wins deterministically.

3. LABELS
   Strategy: Three-way set merge
   - Compute ancestor label set (from merge base)
   - Compute additions and removals per side
   - Result = ancestor + additions_A + additions_B - removals_A - removals_B
   - Tie-breaking: addition wins over removal (bias toward keeping data)
   Conflicts: Effectively never.

4. TITLE / ASSIGNEE
   Strategy: LWW (latest commit timestamp wins)
   Conflict: If both sides changed to different values,
   flag as conflict for human resolution.

5. CONFLICT REPRESENTATION
   - Create merge commit with "Conflict:" trailer listing fields
   - Issue gets "conflict" pseudo-label until resolved
   - `git issue resolve` allows user to pick resolution
```

**Key insight**: Three-way set merge for labels achieves the same result as OR-Set CRDTs for practical cases, using only Git's existing merge base — no Lamport timestamps, no tombstones, no hidden state.

**Why not CRDTs**: Complexity without proportional benefit. Issue conflicts are rare (comments never conflict, state conflicts are low-stakes). The project's value proposition is simplicity — reimplementing CRDTs contradicts that thesis and makes us "git-bug but worse."

---

### DECISION 5: Bridge Architecture
**Plugin protocol (B) + Import/Export first (E), defer live sync**

#### Core principle: The author's vision is about PORTABILITY, not real-time sync.

**v1 ships:**
- `git issue import [--provider github]` — one-time import
- `git issue export [--provider github]` — one-time export
- Stable text protocol for `git-issue-remote-<provider>` plugins
- NO `git issue sync` (bidirectional live sync deferred to v2)

**Bridge protocol** (modeled on `gitremote-helpers(7)`):
```
capabilities     → list, fetch, push, import-all
list [--state=X] → line-oriented issue list (with pagination)
fetch <id>       → single issue with metadata
push <local-ref> → create/update remote issue
import-all       → bulk fetch for migration
```

Protocol speaks **line-oriented text, NOT JSON**. Eliminates the JSON injection class of bugs entirely.

**Bridge implementations** are separate executables, can live in separate repos, iterate on their own release cycle. Core defines the contract; community maintains bridges.

**Why import/export over live sync**: "Migrate from GitHub to GitLab and issues come with you" works perfectly with `git issue import github` then pushing to GitLab. Live sync is a distributed consensus problem — deferred.

---

## Revised Architecture Summary

```
                    NATIVE GIT ISSUES v2
                    =====================

Identity:     UUIDs (7-char display)
Refs:         refs/issues/<uuid>
Data:         Git trailers (subject=title, body=description, trailers=metadata)
Merge:        Field-specific (comments=union, state=LWW, labels=3-way set)
Bridge:       Plugin protocol + import/export (no live sync in v1)
Home:         Standalone tool → format spec submission → ecosystem adoption

Commit Format:
  ┌─────────────────────────────────┐
  │ Fix the login bug               │  ← subject = title
  │                                 │
  │ Description body text...        │  ← body = description
  │                                 │
  │ State: open                     │  ← trailers = metadata
  │ Labels: bug, auth               │
  │ Format-Version: 1               │
  └─────────────────────────────────┘

Ref Layout:
  refs/issues/<uuid-1>  → issue branch (chain of commits)
  refs/issues/<uuid-2>  → issue branch
  refs/issues/<uuid-N>  → issue branch
  (no next-id file — UUIDs need no counter)

Command Set (v1):
  git issue create   [-m "body"] "title"
  git issue comment  <id> -m "text"
  git issue state    <id> --state closed
  git issue ls       [--state open] [--label bug]
  git issue show     <id>
  git issue import   [--provider github]
  git issue export   [--provider github]
```

---

## What Changes from v1 MVP

| v1 MVP (current) | v2 (redesigned) |
|---|---|
| Sequential IDs (0001, 0002) | UUIDs (a7f3b2c) |
| `refs/issues/next-id` plain file | Eliminated (UUIDs need no counter) |
| Pseudo-trailers before body | Proper Git trailers at end |
| `Title:` trailer | Subject line IS the title |
| Per-issue subprocess in `git issue-ls` | Single `for-each-ref` command |
| Hardcoded `.git/` paths | `$(git rev-parse --git-dir)` |
| `local` keyword (non-POSIX) | POSIX-compliant shell |
| `git issues sync` (live bidirectional) | `git issue import/export` (one-shot) |
| JSON string concatenation in bridge | Text-based protocol, no JSON in core |
| Lives in Git source tree fork | Own repository + format spec |
| Merge strategy described only | Three-way set merge implemented |
| No schema versioning | `Format-Version: 1` trailer |

---

## Validation by Prior Art

*(Added after comprehensive prior art research — see [prior-art-analysis.md](prior-art-analysis.md) for full details)*

### Every Council Decision Is Validated by History

| Decision | Prior Art Validation |
|---|---|
| **UUIDs** (Decision 1) | git-bug uses hash-based IDs, Fossil uses SHA hashes, Bugs Everywhere used UUIDs. Sequential IDs were never attempted by any surviving tool. Every successful distributed tracker uses some form of globally unique identifier. |
| **Git trailers** (Decision 2) | git-dit (2016) independently converged on the same design: commits with git trailers as issues. git-appraise used JSON-in-git-notes. Our choice of native trailers enables `for-each-ref` integration that no other tool achieves. |
| **D+C strategy** (Decision 3) | git-bug stayed standalone for 7+ years without ecosystem adoption. Fossil integrated but remained niche. **No previous tool produced a format spec.** Our spec-first strategy is genuinely novel. |
| **Field-specific merge** (Decision 4) | Fossil uses G-Set CRDT (append-only + LWW). git-bug uses operation-based CRDTs with Lamport clocks. Our three-way set merge for labels achieves equivalent results using only git's merge base — simpler than both. |
| **Plugin bridges** (Decision 5) | git-bug's bridges are its most complained-about feature (rate limiting, credentials, identity mapping). git-issue (Spinellis) survived primarily because of bridges. Bridges matter, but must be clean. |

### The Key Differentiator No One Else Has

**The FORMAT SPEC.** Every previous tool's "format" was just whatever their code produced. No standalone, implementable specification exists for a portable issue format. `ISSUE-FORMAT.md` is our primary deliverable and the reason this project could succeed where others didn't.

### The 6 Root Causes of Prior Failure (and Our Mitigations)

1. **Network effects** → We don't replace platforms; import/export enables portability
2. **Non-developer exclusion** → Format is simple enough for any web UI to implement
3. **Weak offline argument** → Reframed as portability, not offline
4. **Merge conflicts** → Field-specific rules (LWW + 3-way set) avoid them
5. **Insufficient resources** → D+C strategy: spec standardization, not platform-building
6. **No format spec** → `ISSUE-FORMAT.md` is deliverable #1

---

## Next Steps (Immediate)

1. **Create `remenoscodes/git-issue` repository** (standalone tool)
2. **Write `ISSUE-FORMAT.md`** — the format spec, independent of any tool
3. **Rewrite core commands** with v2 architecture (UUIDs, proper trailers, `for-each-ref` optimization)
4. **Implement basic merge driver** (at minimum: comments union + state LWW)
5. **Port tests** to new architecture, add error cases and concurrency tests
6. **Harden the GitHub bridge** — text protocol, proper escaping, pagination
7. **Dogfood**: use `git-issue` to track issues for `git-issue` itself
