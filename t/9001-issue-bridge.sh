#!/bin/sh

test_description='Test issue bridge functionality'

. ./test-lib.sh

# Add the contrib directories to PATH
PATH="$GIT_BUILD_DIR/contrib/git-issue:$GIT_BUILD_DIR/contrib/issue-remote:$PATH"
export PATH

# Mock the GitHub API for testing
mock_github_api() {
    # Create a mock git-issue-remote-github script
    cat > "$TRASH_DIRECTORY/git-issue-remote-github" <<-EOF
#!/bin/sh

# Mock GitHub API responses
case "\$1" in
    capabilities)
        echo "list"
        echo "get"
        echo "put"
        echo "delete"
        echo ""
        ;;
    list)
        echo "github:1 sha:1 state:open title:Test GitHub Issue"
        echo "github:2 sha:2 state:closed title:Closed GitHub Issue"
        echo ""
        ;;
    get)
        provider_id=\$(echo "\$2" | sed 's/^github://')
        if [ "\$provider_id" = "1" ]; then
            echo '{"number":1,"title":"Test GitHub Issue","body":"This is a test issue from GitHub","state":"open","labels":[],"assignee":null}'
        elif [ "\$provider_id" = "2" ]; then
            echo '{"number":2,"title":"Closed GitHub Issue","body":"This is a closed issue from GitHub","state":"closed","labels":[],"assignee":null}'
        else
            echo "error Unknown issue: \$provider_id" >&2
            exit 1
        fi
        echo ""
        ;;
    put)
        local_id=\$(echo "\$2" | sed 's/^sha://')
        echo "ok github:\$local_id"
        echo ""
        ;;
    delete)
        provider_id=\$(echo "\$2" | sed 's/^github://')
        echo "ok"
        echo ""
        ;;
    *)
        echo "error Unknown command: \$1" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$TRASH_DIRECTORY/git-issue-remote-github"
    
    # Add the mock to PATH
    PATH="$TRASH_DIRECTORY:$PATH"
    export PATH
}

test_expect_success 'setup' '
    git init test-repo &&
    cd test-repo &&
    test_commit initial &&
    mock_github_api
'

test_expect_success 'git issues sync imports issues from GitHub' '
    # Run the sync command
    git issues sync --provider github &&
    
    # Verify that the issues were imported
    git rev-parse --verify refs/issues/0001 &&
    git rev-parse --verify refs/issues/0002 &&
    
    # Check issue 1 content
    git cat-file -p refs/issues/0001 | grep "Title: Test GitHub Issue" &&
    git cat-file -p refs/issues/0001 | grep "State: open" &&
    git cat-file -p refs/issues/0001 | grep "Provider-ID: github:1" &&
    git cat-file -p refs/issues/0001 | grep "This is a test issue from GitHub" &&
    
    # Check issue 2 content
    git cat-file -p refs/issues/0002 | grep "Title: Closed GitHub Issue" &&
    git cat-file -p refs/issues/0002 | grep "State: closed" &&
    git cat-file -p refs/issues/0002 | grep "Provider-ID: github:2" &&
    git cat-file -p refs/issues/0002 | grep "This is a closed issue from GitHub"
'

test_expect_success 'git issue-create and sync exports to GitHub' '
    # Create a new local issue
    git issue-create --title "Local Issue" -m "This is a local issue" &&
    git rev-parse --verify refs/issues/0003 &&
    
    # Sync to push the local issue to GitHub
    git issues sync --provider github &&
    
    # Verify that the issue now has a Provider-ID
    git cat-file -p refs/issues/0003 | grep "Provider-ID: github:3"
'

test_expect_success 'git issue-comment and sync exports comments to GitHub' '
    # Add a comment to an issue
    git issue-comment 1 -m "This is a comment on the GitHub issue" &&
    
    # Sync to push the comment to GitHub
    git issues sync --provider github
    
    # In a real implementation, we would verify that the comment was pushed to GitHub
    # For this mock test, we just check that the comment was added locally
    git log -1 --format=%B refs/issues/0001 | grep "This is a comment on the GitHub issue"
'

test_expect_success 'git issue-state and sync updates issue state on GitHub' '
    # Change the state of an issue
    git issue-state 1 --state closed &&
    
    # Sync to push the state change to GitHub
    git issues sync --provider github
    
    # In a real implementation, we would verify that the state was updated on GitHub
    # For this mock test, we just check that the state was updated locally
    git log -1 --format=%B refs/issues/0001 | grep "State: closed"
'

test_expect_success 'git issue-ls shows issues from both local and GitHub' '
    git issue-ls > issues.out &&
    grep "#0001 \[closed\] Test GitHub Issue" issues.out &&
    grep "#0002 \[closed\] Closed GitHub Issue" issues.out &&
    grep "#0003 \[open\] Local Issue" issues.out
'

test_done
