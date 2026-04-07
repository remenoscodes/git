# Active Context

This document records the current work focus, active decisions, and ongoing changes in the project.

## Current Focus

We are preparing to contribute to the Git project by implementing a native Git issues system with bridges to external providers. Our focus includes:
- Designing a native issue tracking system directly in Git
- Creating bridges for bidirectional integration with external providers (GitHub, GitLab)
- Maintaining Git's philosophy of small core, decentralization, and data-first approach
- Following Git's contribution process to propose this feature

## Recent Findings

From our analysis of the Git repository and the native issues proposal, we've learned:
- Git uses a modular architecture with clear separation between porcelain and plumbing commands
- Contributions follow a patch-based email workflow rather than pull requests
- Code is primarily written in C with strict coding guidelines
- There's a comprehensive test framework for validating changes
- Documentation is written in AsciiDoc format
- Git's refs system (`refs/heads/`, `refs/tags/`, etc.) can be extended with a new namespace (`refs/issues/`)
- Git's object model and commit structure can store issue metadata using trailers
- The existing merge machinery can be leveraged for issue synchronization

## Contribution Process

The Git project follows a specific contribution workflow:
1. Choose a starting point (typically master or maint branch)
2. Create separate commits for logically separate changes
3. Write comprehensive commit messages explaining the why, not just the what
4. Include tests for new features or bug fixes
5. Submit patches via email to the mailing list
6. Respond to review feedback and iterate on the patches
7. Wait for integration into one of the integration branches (seen, next, master, maint)

## Current Progress

- Core functionality for issue creation, listing, state management, commenting, and displaying has been implemented and tested.
- All 16 basic tests are passing, demonstrating the stability of the MVP.

## Next Steps

Our immediate next steps for implementing the native Git issues feature are:

### Phase 1: Proof of Concept (2-3 weeks)
- Create a detailed technical specification document in `Documentation/technical/native-issues.txt`
- Implement basic plumbing commands in `contrib/git-issue/`
- Create simple bridge prototype in `contrib/issue-remote/`
- Develop basic tests in `t/90xx-issue-*.sh`

### Phase 2: RFC Submission (1-2 weeks)
- Prepare RFC patches for the mailing list
- Include documentation and minimal implementation
- Submit to `git@vger.kernel.org`

### Phase 3: Community Iteration (4-8 weeks)
- Respond to feedback from the community
- Refine the implementation based on suggestions
- Update documentation and tests

### Phase 4: Core Integration (2-4 weeks)
- Move code from `contrib/` to `builtin/`
- Finalize documentation and tests
- Submit final patch series

<!--
Add more specific details as work progresses.
-->
