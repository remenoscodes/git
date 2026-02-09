# Native Git Issues

> **NOTE**: This proof-of-concept has been superseded by the standalone implementation at [github.com/remenoscodes/git-native-issue](https://github.com/remenoscodes/git-native-issue), which is actively maintained and production-ready (v1.2.1+). Install via:
> ```bash
> brew install remenoscodes/git-native-issue/git-native-issue
> ```
> The standalone version includes:
> - UUIDs instead of sequential IDs (distributed-first)
> - Proper Git trailers with `for-each-ref` optimization
> - Complete bridges for GitHub, GitLab, Gitea, and Forgejo
> - ISSUE-FORMAT.md specification for ecosystem adoption
> - 153 tests (76 core + 36 bridge + 20 merge/fsck + 21 QoL)
>
> This directory contains the original v1 proof-of-concept for historical reference.

---

This directory contains a proof-of-concept implementation of native Git issues with bridges to external providers. The feature enables Git to track issues directly within the repository, using Git's own data structures and mechanisms, while also providing bidirectional integration with external issue tracking systems.

## Philosophy

The design of native Git issues follows several key principles:

* **Small core, large ecosystem**: Keep the core implementation minimal while enabling the community to innovate with bridges and UIs.
* **Data first**: Treat issues and comments as first-class citizens, making them immutable and auditable via Git's commit model.
* **Absolute decentralization**: Avoid dependency on any central server; each clone contains the complete issue history.
* **Reuse of infrastructure**: Leverage existing Git components like packfiles, reflogs, hooks, and merge drivers.
* **Incremental evolution**: Start with contrib and lightweight prototypes, iterate via RFCs, and only move to builtin when mature.
* **Consistent UX**: Extend Git's familiar interface (commits, refs, for-each-ref) to the issue domain.

## Architecture

Native Git issues use a dedicated namespace within Git's reference system:

* `refs/issues/XXXX`: Branches for individual issues (XXXX = zero-padded issue ID)
* `refs/issues/next-id`: Atomic counter for the next available issue ID

Issues are stored as commits with structured metadata in the form of trailers:

* `Title:` string
* `State:` one of `open|closed|...` (default `open`)
* `Labels:` comma-separated values
* `Assignee:` email or username
* `Code-SHA:` SHA of the commit where a bug was reproduced
* `Provider-ID:` optional, format `<provider>:<remote-id>`

Comments and state changes are stored as child commits in the issue branch.

## Commands

### Basic Issue Management

* `git issue-create`: Creates a new issue
  ```
  git issue-create --title "Bug in feature X" -m "Description of the bug" --labels "bug,priority-high"
  ```

* `git issue-comment`: Adds a comment to an existing issue
  ```
  git issue-comment 1 -m "This is a comment on issue #1"
  ```

* `git issue-state`: Changes the state of an issue
  ```
  git issue-state 1 --state closed --release v1.0 --fixed-by a1b2c3d4
  ```

* `git issue-ls`: Lists issues with optional filtering
  ```
  git issue-ls --state open --label bug
  ```

* `git issue-show`: Displays the details of an issue
  ```
  git issue-show 1
  ```

### Bridge to External Providers

* `git issues sync`: Synchronizes issues with external providers
  ```
  git issues sync --provider github
  ```

## Bridge Protocol

The bridge protocol uses a text-based format similar to Git's remote helpers:

1. `capabilities` → response: `list, get, put, delete`
2. `list` → lists `<provider-id> sha:<local-id> state:...`
3. `get <pid>` → returns complete issue JSON
4. `put sha:<local-id>` → creates/updates remote; returns `ok <provider-id>`
5. `delete <pid>` → deletes remote

## Installation

1. Add this directory to your PATH:
   ```
   export PATH="/path/to/git/contrib/git-issue:$PATH"
   ```

2. For bridge functionality, also add the issue-remote directory:
   ```
   export PATH="/path/to/git/contrib/issue-remote:$PATH"
   ```

3. For GitHub integration, set the required environment variables:
   ```
   export GITHUB_TOKEN="your-github-token"
   export GITHUB_OWNER="your-github-username"
   export GITHUB_REPO="your-repository-name"
   ```

## Testing

Basic tests are available in the Git test suite:

* `t/9000-issue-basic.sh`: Tests basic issue functionality
* `t/9001-issue-bridge.sh`: Tests bridge functionality

Run the tests with:
```
cd /path/to/git
make test-9000-issue-basic.sh
make test-9001-issue-bridge.sh
```

## Status

This is a proof-of-concept implementation intended to demonstrate the feasibility and design of native Git issues. It is not yet ready for production use. The next steps are:

1. Submit an RFC to the Git mailing list
2. Gather feedback from the community
3. Refine the implementation based on feedback
4. Move the code to builtin/ for inclusion in Git core

## Contributing

Feedback and contributions are welcome! Please submit patches to the Git mailing list following the standard Git contribution process.
