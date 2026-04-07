# Native Git Issues - Prior Art Analysis

**Date**: 2025-04-23
**Author**: Emerson Soares (remenoscodes@gmail.com)
**Purpose**: Comprehensive survey of every known attempt at distributed issue tracking, their architectures, why they succeeded or failed, and lessons for our v2 design.

---

## The Problem Statement

Linus Torvalds, 2007 ([yarchive.net](https://yarchive.net/comp/linux/bug_tracking.html)):

> "A 'git for bugs', where you can track bugs locally and without a web interface."

The problem is real and acknowledged by everyone from Torvalds himself (2025 Git anniversary interviews) to recurring Hacker News threads spanning two decades. Code is portable because Git is a standard. Issues are not portable because **no standard exists**. Your source code travels with `git clone`, but your project management metadata is trapped in a proprietary silo.

---

## 1. The Graveyard (2005-2015)

These tools established the conceptual framework but failed commercially. Each proved technical feasibility while demonstrating practical insufficiency.

### 1.1 Bugs Everywhere (2005)

| | |
|---|---|
| **Creators** | Aaron Bentley, Chris Ball, W. Trevor King |
| **Language** | Python |
| **Storage** | Files in `.be/` directory alongside code |
| **VCS Support** | Bazaar, Git, Mercurial, Arch |
| **Status** | Dead |

**How it worked**: Created a `.be/` directory in the project root. Each bug was a directory with UUID-named files. Bug metadata (severity, status, assigned-to) stored as text files. Comments stored as individual files within the bug directory. Random file naming minimized merge conflicts for new bugs/comments.

**Why it failed**: The [2008 LWN.net article](https://lwn.net/Articles/281849/) provides the definitive post-mortem: changing a bug's severity in two branches and merging creates a conflict requiring hand-editing. Adding a comment requires a VCS commit -- far more work than typing in a web form. No web interface, so non-developers couldn't use it.

**Lesson**: File-based storage that branches and merges alongside code **creates** conflicts rather than resolving them. The data model matters more than the storage location.

### 1.2 ticgit (2008)

| | |
|---|---|
| **Creator** | Scott Chacon (co-founder of GitHub, author of "Pro Git") |
| **Language** | Ruby |
| **Storage** | Separate orphan branch called `ticgit` |
| **Status** | Dead |

**Innovation**: Stored tickets in a separate orphan branch, not in the working tree. This kept the main codebase clean while still using git as the backend.

**Why it died**: Scott Chacon literally went on to build GitHub -- the centralized platform that made distributed issue tracking unnecessary for most developers. The tool had performance issues and required a Ruby environment.

**Lesson**: Even the co-founder of the world's largest code hosting platform started by trying to solve distributed issue tracking. The problem's gravity is undeniable.

### 1.3 Ditz (2008)

| | |
|---|---|
| **Creator** | William Morgan |
| **Language** | Ruby |
| **Storage** | YAML files in `.ditz/` directory |
| **Status** | Dead |

Lightweight distributed issue tracker for DVCS. Stored issues in human-editable line-based files. Same category as Bugs Everywhere but with a cleaner format. Also dead.

### 1.4 dist-bugs Working Group (~2008-2012)

The closest thing to a standardization effort. A working group that emerged around 2008 to "investigate and develop distributed bug tracking systems" and "break bugs out of their centralised data silos." Catalogued existing tools (Bugs Everywhere, ScmBug, DisTract, DITrack, ticgit, Ditz) but **never produced a formal specification**. Went dormant without output.

**Lesson**: Even a dedicated working group couldn't produce a standard. The problem requires a reference implementation first, then a spec -- not the reverse.

---

## 2. The Innovators (2015-2018)

### 2.1 git-appraise (Google, 2015)

| | |
|---|---|
| **Creator** | Omar Jarjur at Google |
| **Language** | Go |
| **Storage** | Git notes under `refs/notes/devtools/*` |
| **Type** | Code review (not issue tracking) |
| **Status** | Dead (~2019) |

**Architecture**: The most architecturally elegant tool in this survey. Stored all code review metadata as git notes under four specialized refs:
- `refs/notes/devtools/reviews` -- review requests
- `refs/notes/devtools/discuss` -- human comments
- `refs/notes/devtools/ci` -- CI/build results
- `refs/notes/devtools/analyses` -- robot/static-analysis comments

Each item stored as a **single line of JSON**, enabling automatic merging via `cat_sort_uniq` strategy. Zero server-side setup required.

**Why it failed**: GitHub Pull Requests and GitLab Merge Requests became the de facto code review standard. Google didn't dogfood it (uses Critique internally). CLI-only UX in a world that expects browser-based review.

**Lesson**: The `refs/notes/` data model is genuinely brilliant. But a tool without organizational adoption pressure behind it cannot compete with platforms. **Our format spec strategy (D+C) directly addresses this** -- we're not trying to replace platforms, we're trying to standardize the data format.

### 2.2 git-dit (2016-2017)

| | |
|---|---|
| **Creators** | Julian Ganz, Matthias Beyer |
| **Language** | Rust (from Bash proof-of-concept) |
| **Storage** | Git commits as issues (empty commits with trailers) |
| **Status** | Dead |

**Architecture**: Each issue is a git commit. Each comment is also a commit referencing its parent. Metadata stored via **git trailers**. Issues tracked in separate refs. No files in the working tree.

**Why it failed**: Never reached 1.0. Two-person project. Competed with git-bug (which launched in 2018 with better UX). Proposed an RFC to the git mailing list for "git enumerations" but gained no traction.

**Critical insight for us**: git-dit's data model (commits with trailers as issues) is **remarkably similar to our v2 design**. They proved the concept works but failed on execution and adoption. Our v2 architecture independently converged on the same fundamental design -- commits with proper git trailers, stored in separate refs, no files in the tree. This validates our approach while warning us that technical correctness alone doesn't guarantee adoption.

### 2.3 SIT (Serverless Information Tracker, 2017)

| | |
|---|---|
| **Creator** | Yurii Rashkovskii |
| **Language** | Rust |
| **Storage** | Transport-agnostic immutable records |
| **Status** | Dormant |

**Architecture**: Over-ambitious scope. Not git-specific -- designed to work with Git, Dropbox, USB drives, or anything that copies files. Immutable, append-only records stored as directories of files.

**Why it stalled**: By generalizing from "issue tracker" to "information tracker," lost focus. One-person project. Being VCS-agnostic meant it couldn't leverage git's features deeply.

**Lesson**: Tight integration with git (using its object store, transport, and refs) is a feature, not a limitation. Our decision to build on git's native plumbing is correct.

---

## 3. The Survivors

### 3.1 git-bug (2018-present) -- The Current State of the Art

| | |
|---|---|
| **Creator** | Michael Mure |
| **Language** | Go |
| **Storage** | Git objects under `refs/bugs/<id>` |
| **Stars** | ~9,662 |
| **License** | GPL v3 |
| **Status** | Active (burst of releases May 2025 after 2.5-year gap) |

#### Architecture

git-bug is the most technically sophisticated distributed issue tracker ever built:

1. **Operation-based CRDTs**: Instead of storing current state, stores the history of changes (CreateOp, AddCommentOp, SetTitleOp, etc.). Current state is computed by replaying operations deterministically.

2. **Lamport logical clocks**: Not wall-clock time. Simple counters establishing causal ordering. Stored as tree entry names (e.g., `create-clock-14`) referencing empty blobs -- elegant hack with zero overhead.

3. **DAG-per-bug model**: Concurrent edits create merge commits forming a DAG for that bug. Deterministic ordering: Lamport clocks respect DAG structure, ties broken lexicographically.

4. **Hash-based IDs**: Operation IDs are `hash(json(operation))`. Entity IDs are hash of first operation. Content-addressable, like git itself. Nonces prevent collisions.

5. **No file pollution**: Uses git's object storage directly. Working tree stays clean.

6. **Multiple UIs**: CLI, interactive TUI, web UI, and GraphQL API -- all in a single Go binary.

7. **Bridges**: Bidirectional sync with GitHub, GitLab, Jira (with persistent pain points around rate limiting, credentials, and identity mapping).

#### Strengths

- Technically elegant CRDT model that truly solves distributed conflict resolution
- True offline-first: no server, no database, no network required
- Blazing fast local operations (in-memory caching)
- Single Go binary distribution
- The most feature-complete distributed issue tracker

#### Weaknesses

- **After 7+ years, still lacks assignees** (#72 open since Nov 2018), milestones, and priorities
- 2.5-year release gap (v0.8.0 Nov 2022 to v0.8.1 May 2025) -- bus factor of 1
- Bridge fragility: rate limiting, credential management, identity mapping problems
- GPL v3 license limits embedding in proprietary workflows
- CRDT complexity is overkill for most issue tracking scenarios
- No organizational adoption -- used by individuals and small teams only
- The web UI is explicitly "not feature-complete"

#### Why It Hasn't Become a Standard

1. **Network effects**: GitHub Issues requires a browser. git-bug requires `go install` + CLI knowledge.
2. **Non-developer exclusion**: Bug reporters need web forms, not `git commit`.
3. **GPL license**: Copyleft limits integration.
4. **Missing basic features**: After 7 years without assignees, it's hard to adopt as primary tracker.
5. **No format spec**: git-bug's data model is excellent but exists only as one project's implementation, not a community standard.

#### Lessons for Our v2

- **The CRDT model is beautiful but unnecessary for our use case**. Issue conflicts are rare -- comments never conflict, state conflicts are low-stakes. Three-way set merge for labels + LWW for scalars achieves 99% of what CRDTs provide with 10% of the complexity. Our council decision on this was correct.
- **The format spec is the missing piece**. git-bug proved the concept works technically but couldn't achieve ecosystem adoption because there's no standard for others to implement against. Our D+C strategy (standalone tool + format spec submission) directly addresses this gap.
- **Bridges must be a first-class concern**, not an afterthought. Bridge fragility is git-bug's biggest user-facing problem.
- **A web UI is not optional** for any tool that aspires to broad adoption. But it doesn't need to be built in v1 -- it needs to be architecturally possible.

### 3.2 git-issue by Diomidis Spinellis (2016-present)

| | |
|---|---|
| **Creator** | Diomidis Spinellis (professor, author of "Code Reading") |
| **Language** | POSIX Shell |
| **Storage** | Files in separate orphan `git-issue` branch |
| **Stars** | ~808 |
| **Status** | Semi-active |

**Architecture**: Issues stored as files in a separate branch. Bidirectional bridges to GitHub and GitLab. Pure POSIX shell, minimal dependencies.

**Why it survived**: GitHub/GitLab bridges are the killer feature -- work offline, sync to/from GitHub. Minimal dependencies. Pragmatic design that complements rather than replaces platforms.

**Lesson**: Pragmatism wins. Don't try to replace GitHub -- complement it with portability.

### 3.3 Fossil (2006-present) -- The Only True Success Story

| | |
|---|---|
| **Creator** | D. Richard Hipp (creator of SQLite) |
| **Language** | C |
| **Storage** | Single SQLite database file |
| **Status** | Active, healthy, self-hosting |

#### Architecture

Fossil stores its entire repository -- source code, wiki, forum posts, and **tickets** -- in a single SQLite database file. The ticket system is built on **ticket change artifacts** -- immutable, content-addressed blobs. The system materializes two SQL tables from artifacts:

- **`TICKET` table**: One row per ticket, current state (derived by replaying all change artifacts in timestamp order)
- **`TICKETCHNG` table**: One row per change, complete audit trail

These tables are derived data, reconstructable via `fossil rebuild`. Only raw artifacts are synced. Default fields include type, status, subsystem, priority, severity, resolution, title, comment -- **all fully customizable**.

#### The CRDT Model That Works

Fossil's "bag of artifacts" is a **G-Set (Grow-only Set) CRDT**:
1. Artifacts are immutable
2. Artifacts can be added but never removed
3. Repositories synchronize by computing the union of their artifact sets
4. Tickets do not branch -- no concept of conflicting states
5. Field values resolved by last-write-wins (timestamp) or append (comments)

This means: no merge conflicts on tickets, ever. No data loss. Deterministic state. Mathematically proven strong consistency using only peer-to-peer communication.

#### The Unified Timeline

Fossil's timeline view displays all project activity in one stream: commits, ticket changes, wiki edits, forum posts. This "situational awareness" is enormously valuable for small-to-medium teams.

#### Why Fossil Proves the Concept

- Issues stored in the repository survive `fossil clone`
- Offline ticket creation/modification works perfectly
- Single binary, zero-configuration self-hosting
- SQLite's ACID transactions provide atomic consistency
- Used in production for 17+ years (SQLite, Tcl/Tk, Fossil itself)

#### Why Fossil Hasn't Displaced Git

- Designed for "cathedral-style" small teams (SQLite = ~5 core committers)
- Ticket UI is underdeveloped compared to GitHub/Jira
- Limited email notifications
- Doesn't scale to very large projects (60K+ files exceed design load)
- GitHub's 100M+ developer network effect is insurmountable

#### Lessons for Our v2

- **The CRDT model works for tickets**. Fossil's G-Set approach is simple, proven, and mathematically sound. Our field-specific merge rules (comments=union, state=LWW, labels=three-way set) are a direct descendant of this philosophy.
- **The unified timeline is powerful**. A `git log` that interleaves issue activity with commits would provide similar situational awareness.
- **Self-hosting must be easy**. Fossil succeeds partly because a server is a single binary + 2-line CGI script.
- **Issues are project data and should be versioned**. This is the foundational insight. GitHub Issues exist only as API state on GitHub's servers.

---

## 4. Community Sentiment & Landscape

### 4.1 Hacker News: The Recurring Cycle

The topic surfaces on HN repeatedly, with at least 7 major threads between 2016-2025:

| Year | Thread | Topic |
|------|--------|-------|
| 2016 | [HN #10905482](https://news.ycombinator.com/item?id=10905482) | "We need distributed bug tracking now" |
| 2017 | [HN #13732598](https://news.ycombinator.com/item?id=13732598) | Show HN: git-dit |
| 2018 | [HN #17782121](https://news.ycombinator.com/item?id=17782121) | Show HN: git-bug |
| 2020 | [HN #22831604](https://news.ycombinator.com/item?id=22831604) | git-bug: "what to do when GitHub is down" |
| 2022 | [HN #33730417](https://news.ycombinator.com/item?id=33730417) | git-bug v0.8 release |
| 2022 | [HN #31984450](https://news.ycombinator.com/item?id=31984450) | "What comes after Git" |
| 2025 | [HN #43971620](https://news.ycombinator.com/item?id=43971620) | git-bug with bridges |

The 2016 thread articulated it best: "if issue tracking and code reviews were based on a common, distributed system like git itself, companies could compete on features and UX without having the advantage of locking in users with high migration costs."

**Pattern**: Each time a new tool surfaces, there is genuine excitement followed by low sustained adoption. The cycle has repeated for nearly two decades.

### 4.2 The GitHub/GitLab Lock-in Problem

GitHub does **not** provide native issue export functionality. Users must use the API with significant limitations (issues/PRs mixed, comments require separate calls, no bulk export UI, rate limiting). Multiple ad-hoc export tools exist ([gh2md](https://github.com/mattduck/gh2md), CSV exporters with 700+ stars).

Migration between platforms is painful: GitLab provides an importer with imperfect metadata fidelity. Bitbucket issues are not automatically imported. Recent Codeberg migration waves (2025) highlight ongoing anxieties.

**The fundamental asymmetry**: Code is portable because Git is a standard. Issues are not portable because there is no standard.

### 4.3 The "Why Not Just Use Email" Argument

Torvalds has consistently maintained email is the superior bug reporting mechanism (no account required, organic routing via CC, threaded discussions, decentralized). Drew DeVault and SourceHut implement this philosophy as a platform.

**The counter-argument**: The email model works for the kernel because Linux has a hierarchical maintainer structure with experienced developers. For most open-source projects, requiring someone to set up a git repository and run CLI commands to file a bug is unrealistic.

### 4.4 Linus's Position (Updated 2025)

In 2025 Git 20th anniversary interviews with both [GitHub](https://github.blog/open-source/git/git-turns-20-a-qa-with-linus-torvalds/) and [GitLab](https://about.gitlab.com/blog/2025/04/07/celebrating-gits-20th-anniversary-with-creator-linus-torvalds/), Torvalds **highlighted the need for better unification of bug tracking and issue systems, which remain fragmented across platforms.** He also stated Git "did what I needed within the first year, and when it did what I needed, I lost interest."

### 4.5 Gitster's Implicit Position

Junio C Hamano has not made public statements about adding issue tracking to Git core. His position is inferred: **Git's development itself uses no issue tracker** -- everything flows through the mailing list, which he manages. This has persisted for 20 years. The absence of discussion about issue tracking in 20 years of maintainership is itself a strong signal.

---

## 5. The Standards Gap

### No Formal Standard Exists

There is **no RFC, W3C spec, IETF standard, or equivalent** for a portable issue tracking format. This is the critical gap that our project aims to fill.

### De Facto Formats

| Tool | Format | Interoperable? |
|------|--------|---------------|
| git-bug | JSON blobs in git objects (CRDT ops) | No -- git-bug only |
| Fossil | SQLite artifacts | No -- Fossil only |
| git-dit | Git commits with trailers | No -- git-dit only |
| SIT | Files in directories | No -- SIT only |
| git-issue (Spinellis) | Files in orphan branch | No -- git-issue only |
| Bugs Everywhere | Files in `.be/` | No -- BE only |

Each tool invented its own format. No two tools can read each other's data. git-bug's bridge system is the closest thing to interoperability, but it's adapter-pattern integration, not standardization.

**This is exactly why our D+C strategy prioritizes the FORMAT SPEC over the tool.**

---

## 6. Comparative Architecture Table

| Dimension | Our v2 | git-bug | Fossil | git-dit | git-appraise |
|-----------|--------|---------|--------|---------|-------------|
| **Storage** | Commits under `refs/issues/<uuid>` | Git objects under `refs/bugs/<id>` | SQLite artifacts | Git commits under refs | Git notes under `refs/notes/devtools/` |
| **Data format** | Git trailers in commit messages | JSON blobs | Artifact blobs | Git trailers | Single-line JSON |
| **ID scheme** | UUIDv4 (7-char display) | Hash of first operation | SHA hash | Hash-based | Commit SHA |
| **Conflict resolution** | Field-specific (LWW + 3-way set) | Operation-based CRDT | G-Set CRDT (LWW) | DAG-based | Line dedup |
| **Native git tools** | `for-each-ref`, `interpret-trailers` | None -- custom tooling | None -- SQLite | Some | `git notes` |
| **Language** | Shell (v1), C path | Go | C | Rust | Go |
| **Complexity** | Low | High | Medium | Medium | Low |
| **Web UI** | Deferred | Built-in (partial) | Built-in | None | Separate project |
| **Bridges** | Plugin protocol (v1: import/export) | GitHub, GitLab, Jira | None (not needed) | None | None |
| **Format spec** | Yes (ISSUE-FORMAT.md) | No | Documented but Fossil-specific | No | No |

---

## 7. Why Previous Attempts Failed: The 6 Root Causes

### RC1: Network Effects Favor Centralization

Bug trackers are communication hubs between developers and users. Distributing the conversation fractures it. As LWN.net stated in 2008: "Any distributed bug tracking system which does not facilitate this wider conversation will not be successful."

**Our mitigation**: We don't try to replace centralized platforms. Import/export bridges make issues portable *between* platforms. The format spec allows platforms to adopt native support.

### RC2: Non-Developers Are Excluded

Bug reporters need a web form, not `git clone && git commit`. Every CLI-only tool excluded 95% of potential users.

**Our mitigation**: v1 is intentionally CLI-only for developers. But the architecture (trailers in commits) is simple enough that any web UI can display and create issues. The format spec enables platform-native UIs.

### RC3: The Offline Argument Was Weak

Unlike code (where offline work is common), bug triage is inherently collaborative. Developers rarely need to file bugs while disconnected.

**Our reframing**: The value isn't "offline bug filing" -- it's **portability**. "Imagine migrating from GitHub to GitLab and your issue history comes with the code." That's the pitch.

### RC4: Merge Conflicts on Metadata

File-based trackers (Bugs Everywhere, Ditz) create irreconcilable merge conflicts on metadata changes. Only CRDT-based approaches (git-bug, Fossil) solved this properly.

**Our solution**: Field-specific merge rules. Comments = union (append-only). State = LWW. Labels = three-way set merge using git merge base. This achieves CRDT-equivalent results using only git's existing primitives.

### RC5: No One Had Enough Resources

Most were 1-3 person projects competing against platforms backed by billions.

**Our mitigation**: The D+C strategy. We're not trying to build a platform. We're defining a format and building a reference implementation. If the Git project blesses the format, platforms have incentive to adopt it.

### RC6: No Format Spec Existed

Each tool invented its own incompatible format. No ecosystem could form around any of them.

**Our core thesis**: The FORMAT SPEC is the value, not the tool. `ISSUE-FORMAT.md` is the deliverable that no previous project produced. If two tools can read the same `refs/issues/` namespace, we win.

---

## 8. What Our v2 Does Differently

### Unique Differentiator: The Format Spec

No previous tool produced a standalone, implementable format specification independent of any particular tool. Every tool's "format" was just whatever their code produced. Our v2 explicitly separates the spec (`ISSUE-FORMAT.md`) from the implementation (`git-issue`).

### Native Git Integration

Our design exclusively uses git's own machinery:
- `git for-each-ref --format='%(contents:subject) %(trailers:key=State,valueonly)'` for listing
- `git interpret-trailers` for creating/parsing metadata
- Standard git refs for storage
- Standard git transport for sync

No JSON, no binary formats, no custom serialization. This means **any tool that can read git commits can read our issues**.

### Simplicity as Strategy

git-bug's CRDT + Lamport clocks + DAG model is technically elegant but complex. Our design uses only concepts git developers already know: commits, trailers, refs, merge bases. The complexity gap is deliberate -- simpler systems are easier to standardize, implement, and maintain.

### The D+C Political Strategy

git-bug stayed standalone and hoped for adoption. We explicitly plan to submit the FORMAT SPEC (not the tool) to `git@vger.kernel.org`. The framing: "Here is a format for `refs/issues/` with 1 year of production use. We ask you to bless the format, not merge our tool." This follows Git's precedent of documenting formats (`gitformat-pack`, `gitformat-index`).

---

## 9. Summary: Lessons Integrated into v2 Architecture

| Lesson from Prior Art | How v2 Addresses It |
|---|---|
| Sequential IDs don't work distributed (all tools) | UUIDv4 with 7-char abbreviated display |
| File-based storage creates merge conflicts (BE, Ditz) | Commits in separate refs, not files in tree |
| CRDTs are overkill for issue tracking (git-bug) | Field-specific rules: LWW + 3-way set merge |
| No format spec = no ecosystem (all tools) | ISSUE-FORMAT.md as primary deliverable |
| CLI-only excludes users (all tools) | Format simple enough for any UI to implement |
| Bridge fragility kills adoption (git-bug) | Plugin protocol, text-based, no JSON in core |
| Single binary is powerful (Fossil, git-bug) | Shell prototype, clear path to C rewrite |
| Unified timeline matters (Fossil) | Issues in `refs/issues/` visible to `git log` |
| Git community values format specs (Git project) | D+C strategy: spec first, then standardization |
| Linus's 2007 vision is still unmet (Torvalds) | This project is the direct answer |

---

## Sources

### Primary Sources
- [Linus Torvalds on Bug Tracking (2007 LKML)](https://yarchive.net/comp/linux/bug_tracking.html)
- [Git turns 20: Q&A with Linus Torvalds (GitHub Blog, 2025)](https://github.blog/open-source/git/git-turns-20-a-qa-with-linus-torvalds/)
- [Git 20th Anniversary Interview (GitLab, 2025)](https://about.gitlab.com/blog/2025/04/07/celebrating-gits-20th-anniversary-with-creator-linus-torvalds/)
- [Celebrating 15 years of Git: Interview with Junio Hamano (GitHub Blog, 2020)](https://github.blog/open-source/git/celebrating-15-years-of-git-an-interview-with-git-maintainer-junio-hamano/)

### Analysis & Commentary
- [Distributed bug tracking (LWN.net, 2008)](https://lwn.net/Articles/281849/)
- [Current State of Distributed Issue Tracking (Matej Cepl, 2013)](https://matej.ceplovi.cz/blog/current-state-of-the-distributed-issue-tracking.html)
- [The state of distributed bug trackers (Jelmer Vernooij)](https://www.jelmer.uk/distributed-bug-trackers.html)
- [Distributed Issue Tracking (nullprogram, 2009)](https://nullprogram.com/blog/2009/02/14/)
- [The advantages of an email-driven git workflow (Drew DeVault)](https://drewdevault.com/2018/07/02/Email-driven-git.html)
- [Mailing lists vs GitHub (begriffs)](https://begriffs.com/posts/2018-06-05-mailing-list-vs-github.html)
- [Weird things about git #2: no bug tracking (apenwarr, 2008)](https://apenwarr.ca/log/20080628)

### Tools Surveyed
- [git-bug Repository](https://github.com/git-bug/git-bug) and [Data Model](https://github.com/git-bug/git-bug/blob/master/doc/model.md)
- [Fossil SCM](https://fossil-scm.org/) and [Ticket System](https://fossil-scm.org/home/doc/trunk/www/tickets.wiki)
- [Why SQLite Does Not Use Git](https://sqlite.org/whynotgit.html)
- [google/git-appraise](https://github.com/google/git-appraise)
- [git-dit/git-dit](https://github.com/git-dit/git-dit)
- [sit-fyi/sit](https://github.com/sit-fyi/sit)
- [dspinellis/git-issue](https://github.com/dspinellis/git-issue)
- [schacon/ticgit](https://github.com/schacon/ticgit)
- [Bugs Everywhere](https://bugs-everywhere.readthedocs.io/)
- [dist-bugs Working Group](http://dist-bugs.branchable.com/)

### Hacker News Discussions
- [HN: "We need distributed bug tracking" (2016)](https://news.ycombinator.com/item?id=10905482)
- [HN: Show HN git-dit (2017)](https://news.ycombinator.com/item?id=13732598)
- [HN: Show HN git-bug (2018)](https://news.ycombinator.com/item?id=17782121)
- [HN: git-bug when GitHub is down (2020)](https://news.ycombinator.com/item?id=22831604)
- [HN: git-bug v0.8 (2022)](https://news.ycombinator.com/item?id=33730417)
- [HN: "What comes after Git" (2022)](https://news.ycombinator.com/item?id=31984450)
- [HN: git-bug with bridges (2025)](https://news.ycombinator.com/item?id=43971620)
- [HN: GitHub lock-in (2016)](https://news.ycombinator.com/item?id=11138201)
- [HN: GitHub to Codeberg migration (2025)](https://news.ycombinator.com/item?id=46097829)
