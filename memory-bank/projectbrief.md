# Project Brief

## Overview
The project aims to implement a native Git issues system within the Git core, along with a mechanism for bidirectional integration with external providers like GitHub and GitLab. The goal is to maintain a minimal core while allowing the community to innovate around bridges and UIs.

## Objectives
- Implement a self-contained issues system using `refs/issues/*`.
- Enable distributed-first issue management, allowing offline creation, editing, and closing of issues.
- Maintain a minimal core with less than 2k LOC in C.
- Utilize existing Git infrastructure like packfiles, reflogs, hooks, and merge drivers.
- Develop executable helpers for bridges to external providers.

## Current Progress
- Core functionality for issue creation, listing, state management, commenting, and displaying has been implemented and tested.
- All 16 basic tests are passing, demonstrating the stability of the MVP.
- The MVP functionality is currently implemented in shell script, with plans to transition to C in the future.

## Next Steps
- Enhance bridge functionality for integration with external providers.
- Improve documentation and user guides.
- Gather feedback from early adopters and iterate on the design.
