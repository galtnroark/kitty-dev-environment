#!/bin/bash
# =============================================================================
# git-commit-push.sh - Safely commit and push changes in correct order
# =============================================================================
# Usage: ./scripts/git-commit-push.sh
#
# This script:
# 1. Commits and pushes ALL submodules first
# 2. Then updates parent repo to track new submodule commits
# 3. Finally commits and pushes parent repo
#
# This ensures submodule commits are pushed BEFORE parent references them
# =============================================================================
set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_NAME="$(basename "$REPO_ROOT")"

echo "🚀 Git Commit & Push: $REPO_NAME"
echo "=================================="
echo ""

submodules_changed=0
main_changed=0

# Step 1: Check and commit/push each submodule (auto-discovered)
if [ -f "$REPO_ROOT/.gitmodules" ]; then
    echo "📦 Step 1: Processing Submodules..."
    echo ""

    submodules=$(git config --file "$REPO_ROOT/.gitmodules" --get-regexp path | awk '{ print $2 }')

    for submodule in $submodules; do
        if [ -d "$REPO_ROOT/$submodule" ]; then
            cd "$REPO_ROOT/$submodule"

            if [[ -n $(git status --porcelain) ]]; then
                echo "📝 Submodule: $submodule (HAS CHANGES)"
                git status --short | sed 's/^/   /'
                echo ""

                # Prompt for commit message
                read -p "   Commit message for $submodule: " commit_msg

                if [ -z "$commit_msg" ]; then
                    echo "   ❌ Skipping (no commit message)"
                else
                    # Add all changes
                    git add -A

                    # Commit with co-author attribution
                    git commit -m "$commit_msg

Co-Authored-By: Claude <noreply@anthropic.com>"

                    # Push
                    echo "   📤 Pushing $submodule..."
                    git push

                    echo "   ✅ $submodule committed and pushed"
                    submodules_changed=1
                fi
                echo ""
            else
                echo "✅ Submodule: $submodule (clean, no changes)"
                echo ""
            fi
        fi
    done
else
    echo "ℹ️  No submodules found"
    echo ""
fi

# Step 2: Update parent repo if submodules changed
cd "$REPO_ROOT"

if [ $submodules_changed -eq 1 ]; then
    echo "📦 Step 2: Updating parent repo to track new submodule commits..."
    echo ""

    # Check which submodules have new commits
    if [[ -n $(git status --porcelain | grep "^.M") ]]; then
        echo "   Submodules with new commits:"
        git status --short | grep -E "^.?M " | sed 's/^/   /'
        echo ""

        # Add submodule updates
        git add -A

        # Auto-commit submodule updates
        submodule_update_msg="chore: update submodule references"

        git commit -m "$submodule_update_msg

Co-Authored-By: Claude <noreply@anthropic.com>"

        main_changed=1
        echo "   ✅ Parent repo updated with new submodule references"
        echo ""
    fi
fi

# Step 3: Check for other changes in main repo
if [[ -n $(git status --porcelain) ]]; then
    echo "📦 Step 3: Processing Main Repository Changes..."
    echo ""
    git status --short | sed 's/^/   /'
    echo ""

    read -p "   Commit message for main repo (or press Enter to skip): " main_commit_msg

    if [ -n "$main_commit_msg" ]; then
        git add -A

        git commit -m "$main_commit_msg

Co-Authored-By: Claude <noreply@anthropic.com>"

        main_changed=1
        echo "   ✅ Main repo committed"
        echo ""
    fi
fi

# Step 4: Push main repo if changes were made
if [ $main_changed -eq 1 ]; then
    echo "📤 Step 4: Pushing main repository..."
    git push
    echo "✅ Main repo pushed"
    echo ""
fi

echo ""
echo "🎉 All changes committed and pushed!"
echo ""
echo "Summary:"
if [ $submodules_changed -eq 1 ]; then
    echo "  ✅ Submodules: committed and pushed"
fi
if [ $main_changed -eq 1 ]; then
    echo "  ✅ Main repo: committed and pushed"
fi
if [ $submodules_changed -eq 0 ] && [ $main_changed -eq 0 ]; then
    echo "  ℹ️  No changes to commit"
fi
