# Shell Functions

Modular shell function library organized by domain.

## Available Modules

| Module | Functions | Purpose |
|--------|-----------|---------|
| **git.sh** | git, git-unstage, git-discard, git-quick, git-pr | Git workflows and PR management |
| **navigation.sh** | n, cd, try, keep | Directory navigation and workspace management |
| **whoami.sh** | whoami-aws, whoami-python | Context and environment information |
| **brew-sync.sh** | brew-sync | Categorized Homebrew package management |
| **env.sh** | env, env-* | On-demand environment preset loading |
| **skills.sh** | skills | AI skills wrapper |

## Small Utilities (in main functions file)

| Function | Purpose |
|----------|---------|
| curl-time | HTTP request timing diagnostics |
| vault-okta-login | HashiCorp Vault authentication via Okta |
| pip | Enhanced pip with Homebrew suggestions |

## Module Structure

Each module follows this pattern:

1. Shebang and header documentation
2. Helper functions (prefixed with `_modulename_`)
3. Public functions (no prefix)
4. Auto-loaded via `.config/shell/functions`

## Adding Modules

Drop new `.sh` files in this directory - they auto-load on next shell start.
