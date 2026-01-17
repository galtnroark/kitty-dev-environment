#!/bin/bash
# =============================================================================
# git-status-all.sh - Check status of all repos (main + submodules)
# =============================================================================
# Usage: ./scripts/git-status-all.sh
#
# Shows:
# - Uncommitted changes in main repo
# - Uncommitted changes in each submodule
# - Unpushed commits
# =============================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_NAME="$(basename "$REPO_ROOT")"

echo "🔍 Repository Status: $REPO_NAME"
echo "=================================="
echo ""

has_changes=0

# Check main repo
echo "📦 Main Repository"
cd "$REPO_ROOT"
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "   Branch: $current_branch"

if [[ -n $(git status --porcelain) ]]; then
    echo "   ⚠️  UNCOMMITTED CHANGES:"
    git status --short | sed 's/^/   /'
    has_changes=1
else
    echo "   ✅ Clean (no changes)"
fi

# Check if ahead of remote
local_commit=$(git rev-parse @ 2>/dev/null || echo "")
remote_commit=$(git rev-parse @{u} 2>/dev/null || echo "no-remote")
if [ -n "$local_commit" ] && [ "$local_commit" != "$remote_commit" ] && [ "$remote_commit" != "no-remote" ]; then
    ahead=$(git rev-list @{u}..@ --count 2>/dev/null || echo "0")
    if [ "$ahead" -gt 0 ]; then
        echo "   ⚠️  $ahead LOCAL COMMIT(S) NOT PUSHED"
        has_changes=1
    fi
fi
echo ""

# Check each submodule (auto-discovered)
if [ -f "$REPO_ROOT/.gitmodules" ]; then
    submodules=$(git config --file .gitmodules --get-regexp path | awk '{ print $2 }')

    for submodule in $submodules; do
        if [ -d "$REPO_ROOT/$submodule" ]; then
            echo "📦 Submodule: $submodule"
            cd "$REPO_ROOT/$submodule"

            # Check if on correct branch
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
            echo "   Branch: $current_branch"

            # Check for uncommitted changes
            if [[ -n $(git status --porcelain) ]]; then
                echo "   ⚠️  UNCOMMITTED CHANGES:"
                git status --short | sed 's/^/   /'
                has_changes=1
            else
                echo "   ✅ Clean (no changes)"
            fi

            # Check if ahead of remote
            local_commit=$(git rev-parse @ 2>/dev/null || echo "")
            remote_commit=$(git rev-parse @{u} 2>/dev/null || echo "no-remote")
            if [ -n "$local_commit" ] && [ "$local_commit" != "$remote_commit" ] && [ "$remote_commit" != "no-remote" ]; then
                ahead=$(git rev-list @{u}..@ --count 2>/dev/null || echo "0")
                if [ "$ahead" -gt 0 ]; then
                    echo "   ⚠️  $ahead LOCAL COMMIT(S) NOT PUSHED"
                    has_changes=1
                fi
            fi

            echo ""
        fi
    done
fi

cd "$REPO_ROOT"

if [ $has_changes -eq 0 ]; then
    echo "🎉 All repositories are clean and synced!"
else
    echo "⚠️  Some repositories have uncommitted changes or unpushed commits"
    echo "Run './scripts/git-commit-push.sh' to commit and push changes"
fi
