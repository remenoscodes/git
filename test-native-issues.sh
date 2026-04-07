#!/bin/sh

# Simple test script for native Git issues
# This script doesn't rely on Git's test framework

set -e  # Exit on error

# Set up the environment
PROJECT_ROOT=$(pwd)
export PATH="$PROJECT_ROOT/contrib/git-issue:$PROJECT_ROOT/contrib/issue-remote:$PATH"

# Create a test repository
echo "Setting up test repository..."
TEST_DIR="test-issues-repo"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init
echo "Test file" > test.txt
git add test.txt
git commit -m "Initial commit"

# Test issue creation
echo "Testing issue creation..."
git issue-create --title "Test issue" -m "This is a test issue"
if ! git rev-parse --verify refs/issues/0001 > /dev/null; then
    echo "FAIL: Issue creation failed"
    exit 1
fi
echo "PASS: Issue created successfully"

# Test issue details
echo "Testing issue content..."
if ! git cat-file -p refs/issues/0001 | grep -q "Title: Test issue"; then
    echo "FAIL: Issue title not found"
    exit 1
fi
if ! git cat-file -p refs/issues/0001 | grep -q "State: open"; then
    echo "FAIL: Issue state not found"
    exit 1
fi
if ! git cat-file -p refs/issues/0001 | grep -q "This is a test issue"; then
    echo "FAIL: Issue description not found"
    exit 1
fi
echo "PASS: Issue content verified"

# Test issue comment
echo "Testing issue comment..."
git issue-comment 1 -m "This is a comment on issue 1"
if ! git log -1 --format=%B refs/issues/0001 | grep -q "This is a comment on issue 1"; then
    echo "FAIL: Issue comment not found"
    exit 1
fi
echo "PASS: Issue comment added successfully"

# Test issue state change
echo "Testing issue state change..."
git issue-state 1 --state closed
if ! git log -1 --format=%B refs/issues/0001 | grep -q "State: closed"; then
    echo "FAIL: Issue state change failed"
    exit 1
fi
echo "PASS: Issue state changed successfully"

# Test issue listing
echo "Testing issue listing..."
if ! git issue-ls | grep -q "#0001 \[closed\] Test issue"; then
    echo "FAIL: Issue not listed correctly"
    exit 1
fi
echo "PASS: Issue listing works"

# Test issue show
echo "Testing issue show..."
if ! git issue-show 1 | grep -q "Issue #1 \[closed\]: Test issue"; then
    echo "FAIL: Issue show failed"
    exit 1
fi
if ! git issue-show 1 | grep -q "This is a test issue"; then
    echo "FAIL: Issue description not shown"
    exit 1
fi
if ! git issue-show 1 | grep -q "This is a comment on issue 1"; then
    echo "FAIL: Issue comment not shown"
    exit 1
fi
echo "PASS: Issue show works"

# Clean up
cd ..
echo "All tests passed!"
