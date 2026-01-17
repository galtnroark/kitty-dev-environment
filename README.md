# Kitty Dev Environment

A config-driven workspace launcher for [Kitty terminal](https://sw.kovidgoyal.net/kitty/) that integrates with Claude Code for AI-assisted development workflows.

## Features

- **Workspace switching** with color-coded terminal themes
- **Modular navigation** for monorepos with submodules
- **Mode selection** (Plan/Design vs Implementation)
- **PRD tracking** with recent PRD history
- **RPC JSON menu** for IoT device debugging
- **gum-powered UI** for beautiful interactive menus

## Quick Start

### Prerequisites

```bash
# Install dependencies
brew install gum yq

# Kitty must have remote control enabled
```

### Installation

```bash
# Clone the repo
git clone https://github.com/galtnroark/kitty-dev-environment.git

# Run the install script
./install.sh
```

### Manual Installation

1. Copy files to your Kitty config:
   ```bash
   cp -r scripts ~/.config/kitty/
   cp workspaces.yaml ~/.config/kitty/
   ```

2. Add to your `~/.config/kitty/kitty.conf`:
   ```
   allow_remote_control yes

   map cmd+shift+m launch --type=overlay --title "Workspace Menu" ~/.config/kitty/scripts/workspace-menu.sh
   ```

3. Reload Kitty config: `Ctrl+Shift+F5`

## Usage

Press `⌘⇧M` to open the workspace menu.

### Navigation
- Arrow keys / `j`/`k` to navigate
- `Enter` to select
- `Esc` or `Ctrl-C` to cancel/go back
- "← Back" option returns to previous level

### Workspace Types

**Simple Workspaces**: Launch directly to a directory with Claude Code

**Modular Workspaces**: Navigate through:
1. Module selection (submodule/subdirectory)
2. Mode selection (Plan/Design or Implement)
3. PRD input (for Implementation mode)

## Configuration

Edit `~/.config/kitty/workspaces.yaml` to customize:

```yaml
repo_roots:
  myproject: "$HOME/code/my-project"

colors:
  myproject:
    background: "#1a1b26"
    foreground: "#c0caf5"
    cursor: "#f7768e"

workspaces:
  - key: "MYPROJECT"
    title_base: "My Project"
    root_ref: "myproject"
    # Optional: add modules and modes for nested navigation
```

### Adding a Simple Workspace

```yaml
workspaces:
  - key: "NEWPROJECT"
    title_base: "New Project"
    root_ref: "newproject"
```

### Adding a Modular Workspace

```yaml
workspaces:
  - key: "MONOREPO"
    title_base: "Monorepo"
    root_ref: "monorepo"
    modules:
      - key: "frontend"
        path: "packages/frontend"
        display_name: "Frontend"
      - key: "backend"
        path: "packages/backend"
        display_name: "Backend"
    modes:
      - key: "PLAN / DESIGN"
        mode_id: "PLAN_DESIGN"
        description: "Architecture and design planning"
      - key: "IMPLEMENT"
        mode_id: "IMPLEMENT"
        description: "Implementation with PRD tracking"
```

## Files

| File | Purpose |
|------|---------|
| `scripts/workspace-menu.sh` | Main menu script |
| `scripts/galt-design.sh` | Theme setter for design mode |
| `scripts/galt-impl.sh` | Theme setter for implementation mode |
| `scripts/ssdd-client.sh` | Theme setter for SSDD workspace |
| `workspaces.yaml` | Workspace configuration |

## Git Helpers for Monorepos

Included are three scripts for managing git repositories with submodules:

```bash
# Copy to your project's scripts/ directory
cp git-helpers/*.sh ~/your-project/scripts/
```

| Script | Purpose |
|--------|---------|
| `git-sync.sh` | Pull main repo + all submodules |
| `git-status-all.sh` | Show status across all repos |
| `git-commit-push.sh` | Commit/push in correct order (submodules first) |

### Why These Scripts?

When working with git submodules, you must:
1. **Push submodules BEFORE parent** - or the parent references commits that don't exist on remote
2. **Pull parent THEN submodules** - or you get detached HEAD states

These scripts automate the correct order and prevent common mistakes.

### Usage

```bash
# Start your day - pull everything
./scripts/git-sync.sh

# Check what changed
./scripts/git-status-all.sh

# End your day - commit & push everything safely
./scripts/git-commit-push.sh
```

The scripts auto-discover submodules from `.gitmodules` - no hardcoded paths needed.

## Dependencies

- [Kitty](https://sw.kovidgoyal.net/kitty/) terminal with `allow_remote_control yes`
- [gum](https://github.com/charmbracelet/gum) - Interactive CLI components
- [yq](https://github.com/mikefarah/yq) - YAML processor
- [Claude Code](https://claude.ai/code) (optional, for AI-assisted development)

## License

MIT
