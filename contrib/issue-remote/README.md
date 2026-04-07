# Git Issue Remote Helpers

This directory contains remote helpers for the native Git issues feature, enabling bidirectional integration with external issue tracking systems.

## Overview

Git issue remote helpers are executables that implement a simple text-based protocol for communicating between Git's native issue system and external issue tracking providers like GitHub, GitLab, Jira, etc.

The remote helpers follow a naming convention of `git-issue-remote-<provider>`, where `<provider>` is the name of the external issue tracking system (e.g., `github`, `gitlab`).

## Protocol

The protocol is text-based and follows a request-response pattern similar to Git's remote helpers. The remote helper reads commands from standard input and writes responses to standard output.

### Commands

1. `capabilities`: Lists the capabilities of the remote helper
   - Response: One capability per line, followed by a blank line
   - Example:
     ```
     list
     get
     put
     delete
     
     ```

2. `list`: Lists all issues from the external provider
   - Response: One issue per line in the format `<provider-id> sha:<local-id> state:<state> title:<title>`, followed by a blank line
   - Example:
     ```
     github:1 sha:1 state:open title:Bug in feature X
     github:2 sha:2 state:closed title:Implement feature Y
     
     ```

3. `get <provider-id>`: Gets the details of a specific issue from the external provider
   - Response: The issue details in JSON format, followed by a blank line
   - Example:
     ```
     {"number":1,"title":"Bug in feature X","body":"Description of the bug","state":"open","labels":["bug","priority-high"],"assignee":"user"}
     
     ```

4. `put sha:<local-id>`: Creates or updates an issue in the external provider
   - Response: `ok <provider-id>` on success, followed by a blank line
   - Example:
     ```
     ok github:1
     
     ```

5. `delete <provider-id>`: Deletes an issue in the external provider
   - Response: `ok` on success, followed by a blank line
   - Example:
     ```
     ok
     
     ```

### Error Handling

If an error occurs, the remote helper should write an error message to standard error and exit with a non-zero status code.

## Field Mapping

The following table shows the mapping between Git issue trailers and external provider fields:

| Trailer local         | Field remote                    |
|-----------------------|---------------------------------|
| `Title:`              | `title`                         |
| Markdown body         | `body`                          |
| `State:`              | `state`                         |
| `Labels:`             | `labels[]`                      |
| `Assignee:`           | `assignee.login`                |
| `Provider-ID:`        | ID of the issue in the remote   |
| `Provider-Comment-ID:`| ID of the comment in the remote |

## Implementing a New Remote Helper

To implement a new remote helper:

1. Create a new executable script or program named `git-issue-remote-<provider>` (e.g., `git-issue-remote-jira`)
2. Implement the protocol described above
3. Place the executable in a directory in your PATH

### Example Implementation Structure

```sh
#!/bin/sh

# Configuration
# These would normally be read from git config
PROVIDER_TOKEN=${PROVIDER_TOKEN:-}
PROVIDER_URL=${PROVIDER_URL:-}

# Helper functions
send_error() {
    echo "error $1" >&2
    exit 1
}

require_config() {
    # Check required configuration
}

# API functions
provider_api_get() {
    # Implement API GET request
}

provider_api_post() {
    # Implement API POST request
}

provider_api_patch() {
    # Implement API PATCH request
}

provider_api_delete() {
    # Implement API DELETE request
}

# Command handlers
cmd_capabilities() {
    echo "list"
    echo "get"
    echo "put"
    echo "delete"
    echo ""
}

cmd_list() {
    # Implement list command
}

cmd_get() {
    # Implement get command
}

cmd_put() {
    # Implement put command
}

cmd_delete() {
    # Implement delete command
}

# Main command loop
while read -r cmd args; do
    case "$cmd" in
        capabilities)
            cmd_capabilities
            ;;
        list)
            cmd_list
            ;;
        get)
            cmd_get "$args"
            ;;
        put)
            cmd_put "$args"
            ;;
        delete)
            cmd_delete "$args"
            ;;
        *)
            send_error "Unknown command: $cmd"
            ;;
    esac
done
```

## Existing Remote Helpers

- `git-issue-remote-github`: Bridge to GitHub Issues

## Testing

Remote helpers can be tested using the `t/9001-issue-bridge.sh` test script, which provides a framework for testing the bridge functionality.

## Contributing

Feedback and contributions are welcome! Please submit patches to the Git mailing list following the standard Git contribution process.
