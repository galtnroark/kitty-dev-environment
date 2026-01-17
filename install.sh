#!/usr/bin/env bash
# =============================================================================
# Install Script for Kitty Dev Environment
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KITTY_CONFIG_DIR="${HOME}/.config/kitty"

echo "╭─────────────────────────────────────────────────╮"
echo "│     Kitty Dev Environment - Installer          │"
echo "╰─────────────────────────────────────────────────╯"
echo ""

# Check dependencies
echo "Checking dependencies..."
missing=()
for cmd in gum yq kitty; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "⚠️  Missing dependencies: ${missing[*]}"
    echo "   Install with: brew install ${missing[*]}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✓ All dependencies installed"
fi

# Create kitty config directory if needed
if [[ ! -d "$KITTY_CONFIG_DIR" ]]; then
    echo "Creating $KITTY_CONFIG_DIR..."
    mkdir -p "$KITTY_CONFIG_DIR"
fi

# Create scripts directory if needed
if [[ ! -d "$KITTY_CONFIG_DIR/scripts" ]]; then
    echo "Creating $KITTY_CONFIG_DIR/scripts..."
    mkdir -p "$KITTY_CONFIG_DIR/scripts"
fi

# Copy scripts
echo "Installing scripts..."
cp -v "$SCRIPT_DIR/scripts/"*.sh "$KITTY_CONFIG_DIR/scripts/"
chmod +x "$KITTY_CONFIG_DIR/scripts/"*.sh

# Copy workspaces.yaml
echo "Installing workspaces.yaml..."
if [[ -f "$KITTY_CONFIG_DIR/workspaces.yaml" ]]; then
    echo "  ⚠️  Backing up existing workspaces.yaml to workspaces.yaml.bak"
    cp "$KITTY_CONFIG_DIR/workspaces.yaml" "$KITTY_CONFIG_DIR/workspaces.yaml.bak"
fi
cp -v "$SCRIPT_DIR/workspaces.yaml" "$KITTY_CONFIG_DIR/"

# Check kitty.conf for required settings
echo ""
echo "Checking kitty.conf..."
KITTY_CONF="$KITTY_CONFIG_DIR/kitty.conf"

if [[ -f "$KITTY_CONF" ]]; then
    needs_remote_control=false
    needs_keybinding=false

    if ! grep -q "^allow_remote_control yes" "$KITTY_CONF"; then
        needs_remote_control=true
    fi

    if ! grep -q "workspace-menu.sh" "$KITTY_CONF"; then
        needs_keybinding=true
    fi

    if $needs_remote_control || $needs_keybinding; then
        echo ""
        echo "Add the following to your kitty.conf:"
        echo ""
        echo "────────────────────────────────────────────"
        $needs_remote_control && echo "allow_remote_control yes"
        echo ""
        $needs_keybinding && echo "map cmd+shift+m launch --type=overlay --title \"Workspace Menu\" ~/.config/kitty/scripts/workspace-menu.sh"
        echo "────────────────────────────────────────────"
        echo ""
    else
        echo "✓ kitty.conf already configured"
    fi
else
    echo "⚠️  No kitty.conf found. Create one with:"
    echo ""
    echo "────────────────────────────────────────────"
    echo "allow_remote_control yes"
    echo ""
    echo "map cmd+shift+m launch --type=overlay --title \"Workspace Menu\" ~/.config/kitty/scripts/workspace-menu.sh"
    echo "────────────────────────────────────────────"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Add the kitty.conf lines shown above (if needed)"
echo "  2. Reload Kitty: Ctrl+Shift+F5"
echo "  3. Press ⌘⇧M to open the workspace menu"
echo ""
echo "Customize your workspaces: $KITTY_CONFIG_DIR/workspaces.yaml"
