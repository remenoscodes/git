# Git (fork) -- Native Git Issues

Fork of git/git with a proof-of-concept for native issue tracking using Git's own data structures. Branch `feat/git-issue` contains shell scripts in `contrib/git-issue/` implementing v1 MVP.

Inherits workspace conventions from `~/CLAUDE.md`.

## Status
- **Version**: v1 MVP (proof-of-concept, superseded by standalone product)
- **State**: dormant (active work moved to git-native-issue standalone)
- **Deploy**: local only

## Stack
- C (Git core)
- Shell scripts (contrib/git-issue/)
- Git test framework (t/ directory, sharness-based)

## Key Commands
```bash
make                                      # Build Git from source
make test                                 # Run full test suite
cd t && sh 9000-issue-basic.sh            # Run issue basic tests
cd t && sh 9001-issue-bridge.sh           # Run issue bridge tests
git issue-create --title "Bug" -m "desc"  # Create an issue (contrib)
git issue-ls --state open                 # List issues (contrib)
```

## Architecture
- `contrib/git-issue/` -- 6 shell scripts: create, comment, state, ls, show, sync
- `t/9000-issue-basic.sh` + `t/9001-issue-bridge.sh` -- 16 tests total
- Issues stored as commits in `refs/issues/<ID>` with structured trailers
- Bridge protocol for GitHub/external provider sync (text-based, similar to remote helpers)
- v2 architecture decisions documented in `Documentation/reviews/council-decisions-v2.md`

## Related Projects
- `git-native-issue` (Homebrew: `remenoscodes/git-native-issue/git-native-issue`) -- standalone production tool, v1.3.3
- `~/source/remenoscodes.claude-git-native-issue` -- Claude Code plugin for git-native-issue
