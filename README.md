# Dotfiles

Personal development environment configuration managed by **Nix Home Manager**.

Declarative, reproducible setup for Neovim + tmux + Ghostty on macOS and Linux.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles

# Run the bootstrap script
cd ~/.dotfiles && ./bootstrap.sh

# Restart your terminal
exec zsh
```

That's it. Everything is installed and configured.

## What's Included

| Component | Description |
|-----------|-------------|
| **Home Manager** | Declarative configuration management |
| **Ghostty** | GPU-accelerated terminal with Catppuccin theme |
| **tmux** | Terminal multiplexer with vim keybindings and Catppuccin theme |
| **Neovim** | Full IDE setup with LSP, completion, debugging |
| **OpenCode** | Terminal AI coding agent with Catppuccin Macchiato, Space leader, and tmux integration |
| **Zsh** | Shell with autosuggestions, syntax highlighting, starship prompt |

## Directory Structure

```
~/.dotfiles/
├── flake.nix              # Nix flake (entry point)
├── home.nix               # Home Manager configuration
├── bootstrap.sh           # One-time setup script
├── ghostty/
│   └── config             # Ghostty terminal config
├── opencode/
│   ├── opencode.json      # OpenCode runtime config
│   ├── opentmux.json      # opentmux layout/config
│   └── tui.json           # OpenCode TUI theme + keybinds
├── tmux/
│   └── tmux.conf          # tmux keybindings and theme
├── nvim/
│   ├── init.lua           # Neovim entry point
│   └── lua/
│       ├── config/        # Core settings
│       └── plugins/       # Plugin configurations
└── bin/
    └── tmux-sessionizer   # Project session switcher (Ctrl-g)
```

## How It Works

Home Manager uses Nix to declaratively manage:

- **Packages** - All dev tools installed via Nix
- **Dotfiles** - Configs symlinked to `~/.config/`
- **Shell** - Zsh with aliases, env vars, plugins
- **Programs** - tmux, git, fzf, starship with native config
- **AI Tools** - OpenCode with managed theme, keybinds, LSP, and permissions
- **Agent UX** - opentmux wrapper and config for tmux-backed OpenCode sessions

### Applying Changes

After editing any config:

```bash
home-manager switch --flake ~/.dotfiles
```

### Rolling Back

```bash
# List generations
home-manager generations

# Roll back to previous
home-manager switch --flake ~/.dotfiles --rollback
```

## Tools Available

All installed automatically via `home.nix`:

- **Editor**: Neovim
- **AI**: OpenCode
- **Search**: ripgrep (rg), fd, fzf, tree
- **Git**: lazygit, git, delta
- **Languages**: Node.js 22, Python 3.12, Lua 5.1
- **LSP Servers**: TypeScript, HTML/CSS/JSON, Ruff, Lua
- **Terminal**: tmux
- **Build Tools**: gcc, gnumake
- **Utilities**: curl, wget, unzip, jq

## Keybindings

### tmux

| Key | Action |
|-----|--------|
| `Ctrl-g` | Open sessionizer (project switcher) |
| `Ctrl-a` | Switch to last session |
| `Ctrl-b` | Prefix key (then press another key) |
| `Ctrl-b [` | Enter copy mode |
| `Ctrl-b c` | New window |
| `Ctrl-b 1-9` | Switch to window |
| `Ctrl-b n/p` | Next/previous window |
| `Ctrl-b "` or `-` | Split horizontally |
| `Ctrl-b %` or `\|` | Split vertically |
| `Ctrl-b h/j/k/l` | Navigate panes |
| `Ctrl-b H/J/K/L` | Resize panes |
| `Ctrl-b x` | Close pane |
| `Ctrl-b z` | Zoom pane |
| `Ctrl-b d` | Detach |
| `Ctrl-b w` | Choose session/window |

### Neovim

Leader key: `<Space>`

| Key | Action |
|-----|--------|
| `ff` | Find files |
| `gf` | Live grep |
| `<leader>,` | Switch buffer |
| `<leader>x` | File explorer (Oil) |
| `gd` | Go to definition |
| `gr` | Go to references |
| `<leader>gg` | LazyGit |

### OpenCode

Leader key: `<Space>`

OpenCode is configured via `~/.config/opencode/` with:

- `catppuccin-macchiato` TUI theme
- Space as the leader key
- Ruff as the Python LSP
- `opentmux` enabled through the OpenCode `plugin` array
- `opentmux.json` managed from dotfiles for tmux layout defaults
- Claude Code fallback support disabled via `OPENCODE_DISABLE_CLAUDE_CODE*`

The `opencode` command is wrapped through `opentmux` from [bin/opencode](/home/vscode/dotfiles/bin/opencode:1), so launching OpenCode from your shell uses the tmux integration by default.

On first run, open `opencode` and use `/connect` to authenticate a provider.

## Customizing

### Adding Packages

Edit `home.nix`:

```nix
home.packages = with pkgs; [
  # ... existing packages
  htop        # Add new package
];
```

Then apply: `home-manager switch --flake ~/.dotfiles`

### Adding Aliases

Edit `home.nix`:

```nix
programs.zsh.shellAliases = {
  # ... existing aliases
  myalias = "my-command";
};
```

### Modifying tmux/Neovim

Edit files directly in `tmux/` or `nvim/`, then apply changes.

## Troubleshooting

### Home Manager command not found

```bash
# Source Nix
. ~/.nix-profile/etc/profile.d/nix.sh
# Or on macOS with daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Flakes not enabled

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Neovim plugins not loading

```vim
:Lazy sync
```

### LSP servers not working

```vim
:Mason
:MasonInstallAll
```

## Updating

```bash
cd ~/.dotfiles
git pull
home-manager switch --flake .
```

In Neovim:
```vim
:Lazy sync
:MasonUpdate
:TSUpdate
```

## License

MIT
