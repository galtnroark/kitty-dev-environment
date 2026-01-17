#!/bin/bash
# =============================================================================
# git-sync.sh - Pull latest changes from all repos (main + submodules)
# =============================================================================
# Usage: ./scripts/git-sync.sh
#
# This script:
# - Pulls the main repository
# - Updates all git submodules to their latest remote commits
# =============================================================================
set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_NAME="$(basename "$REPO_ROOT")"

echo "🔄 Syncing Repository: $REPO_NAME"
echo "=================================="
echo ""

# Pull main repo
echo "📦 Main Repository"
cd "$REPO_ROOT"
git pull
echo "✅ Main repo synced"
echo ""

# Check if there are submodules
if [ -f "$REPO_ROOT/.gitmodules" ]; then
    echo "📦 Updating Submodules..."
    git submodule update --remote --merge
    echo "✅ Submodules synced"
else
    echo "ℹ️  No submodules found"
fi

echo ""
echo "🎉 All repositories synced!"
echo ""
echo "Run './scripts/git-status-all.sh' to check for uncommitted changes"
