# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## What's Managed

| Config | Path | Description |
|--------|------|-------------|
| **Bash** | `~/.bashrc` | Shell config with history settings, aliases, prompt |
| **Neovim** | `~/.config/nvim/` | Lua-based config with lazy.nvim, LSP, Treesitter, Telescope |
| **WezTerm** | `~/.config/wezterm/` | Terminal emulator with cyberdream theme, pane/tab keybindings, WSL support |
| **Zellij** | `~/.config/zellij/` | Terminal multiplexer with catppuccin-mocha theme, vim-style keybindings |
| **SSH** | `~/.ssh/config` | Host configs for GitHub, GitLab instances |
| **Claude Code** | `~/.claude/` | Settings, plugins, skills, statusline |

### Neovim Plugins

LSP (`lspconfig`), completions (`blink-cmp`), fuzzy finder (`telescope`), file tree (`neo-tree`), syntax highlighting (`treesitter`), formatting (`conform`), linting (`lint`), debugging (`debug`), Git signs, which-key, autopairs, todo-comments, indent guides. Go development support via `go.nvim`. Theme: cyberdream.

### WezTerm Keybindings

| Key | Action |
|-----|--------|
| `Ctrl+Shift+O` | Split pane vertically |
| `Ctrl+Shift+E` | Split pane horizontally |
| `Ctrl+Shift+W` | Close current pane |
| `Ctrl+Arrow` | Navigate panes |
| `Alt+[` / `Alt+]` | Switch tabs |
| `Ctrl+Alt+Shift+T` | Open btop in split |
| `Ctrl+Alt+X` | Open zellij in split |

## Setup

### Prerequisites

- [chezmoi](https://www.chezmoi.io/install/)
- [Neovim](https://neovim.io/) (for nvim config)
- [WezTerm](https://wezfurlong.org/wezterm/) (for terminal config)
- [Zellij](https://zellij.dev/) (for multiplexer config)
- [JetBrainsMono Nerd Font](https://www.nerdfonts.com/)

### Install on a New Machine

```sh
# Install chezmoi and apply dotfiles in one command
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <github-username>
```

Or if chezmoi is already installed:

```sh
chezmoi init <github-username>
chezmoi diff    # preview changes
chezmoi apply   # apply changes
```

### Daily Usage

```sh
# Pull latest changes and apply
chezmoi update

# Edit a managed file (opens in $EDITOR, applies on save)
chezmoi edit ~/.bashrc

# Edit directly then sync back to chezmoi source
vim ~/.bashrc
chezmoi re-add

# See what would change
chezmoi diff

# Add a new file to be managed
chezmoi add ~/.config/some/config
```

### Managing This Repo

```sh
# Go to the chezmoi source directory
chezmoi cd

# Standard git workflow from there
git add -A
git commit -m "update configs"
git push
```

## File Naming Conventions

Chezmoi uses special prefixes in the source directory:

| Prefix | Meaning |
|--------|---------|
| `dot_` | Replaced with `.` (e.g. `dot_bashrc` → `.bashrc`) |
| `private_` | File permissions set to `0600` |
| `executable_` | File permissions include execute bit |
| `empty_` | Ensure file exists, even if empty |
