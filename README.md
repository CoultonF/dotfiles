# Dotfiles!

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

| Component        | Description                                                         |
| ---------------- | ------------------------------------------------------------------- |
| **Home Manager** | Declarative configuration management                                |
| **Ghostty**      | GPU-accelerated terminal with Catppuccin theme                      |
| **tmux**         | Terminal multiplexer with vim keybindings and Catppuccin theme      |
| **Neovim**       | Full IDE setup with LSP, completion, debugging                      |
| **OpenCode**     | Terminal AI coding agent with Catppuccin Macchiato and Space leader |
| **Pi**           | Coding agent CLI installed with Bun and managed global settings     |
| **Zsh**          | Shell with autosuggestions, syntax highlighting, starship prompt    |

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
│   └── tui.json           # OpenCode TUI theme + keybinds
├── pi/
│   ├── settings.json      # Pi global agent settings
│   ├── APPEND_SYSTEM.md   # System prompt extension (operator preferences)
│   ├── keybindings.json   # Pi keybinding overrides
│   ├── mcp.json           # MCP server scaffold
│   ├── skills/            # SKILL.md skills (auto-discovered)
│   └── extensions/        # TypeScript extensions (inline-bash, auto-commit-on-exit)
├── omp/
│   └── agent/
│       ├── config.yml      # OMP global agent config (via PI_CONFIG_DIR/PI_CODING_AGENT_DIR)
│       ├── APPEND_SYSTEM.md # OMP global context
│       ├── keybindings.json # Runtime keybinding fallback
│       ├── extensions/      # OMP extension shortcuts
│       └── tools/           # OMP custom tools
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
- **AI Tools** - OpenCode and Pi with managed config

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
- **AI**: OpenCode, Pi
- **Search**: ripgrep (rg), fd, fzf, tree
- **Git**: lazygit, git, delta
- **Languages**: Node.js 22, Python 3.12, Lua 5.1
- **LSP Servers**: TypeScript, HTML/CSS/JSON, Ruff, Lua
- **Terminal**: tmux
- **Build Tools**: gcc, gnumake
- **Utilities**: curl, wget, unzip, jq

## Keybindings

### tmux

| Key                | Action                              |
| ------------------ | ----------------------------------- |
| `Ctrl-g`           | Open sessionizer (project switcher) |
| `Ctrl-a`           | Switch to last session              |
| `Ctrl-b`           | Prefix key (then press another key) |
| `Ctrl-b [`         | Enter copy mode                     |
| `Ctrl-b c`         | New window                          |
| `Ctrl-b 1-9`       | Switch to window                    |
| `Ctrl-b n/p`       | Next/previous window                |
| `Ctrl-b "` or `-`  | Split horizontally                  |
| `Ctrl-b %` or `\|` | Split vertically                    |
| `Ctrl-b h/j/k/l`   | Navigate panes                      |
| `Ctrl-b H/J/K/L`   | Resize panes                        |
| `Ctrl-b x`         | Close pane                          |
| `Ctrl-b z`         | Zoom pane                           |
| `Ctrl-b d`         | Detach                              |
| `Ctrl-b w`         | Choose session/window               |

### Neovim

Leader key: `<Space>`

| Key          | Action              |
| ------------ | ------------------- |
| `ff`         | Find files          |
| `gf`         | Live grep           |
| `<leader>,`  | Switch buffer       |
| `<leader>x`  | File explorer (Oil) |
| `gd`         | Go to definition    |
| `gr`         | Go to references    |
| `<leader>gg` | LazyGit             |

### OpenCode

Leader key: `<Space>`

OpenCode is configured via `~/.config/opencode/` with:

- `catppuccin-macchiato` TUI theme
- Space as the leader key
- Ruff as the Python LSP
- Claude Code fallback support disabled via `OPENCODE_DISABLE_CLAUDE_CODE*`

On first run, open `opencode` and use `/connect` to authenticate a provider.

### Pi

Pi is installed from `@earendil-works/pi-coding-agent` using Bun. The dotfiles repo manages everything Pi auto-discovers under `~/.pi/agent/` via out-of-store symlinks, so edits in `pi/` apply live (run `/reload` inside Pi to pick them up without restarting).

| Path                  | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `pi/settings.json`    | Default provider, model, theme, telemetry, retry/compaction    |
| `pi/APPEND_SYSTEM.md` | Operator preferences appended to Pi's default system prompt    |
| `pi/keybindings.json` | Key remaps for vim-style model cycling and selector navigation |
| `pi/mcp.json`         | MCP server scaffold (empty until populated)                    |
| `pi/skills/`          | Drop-in `SKILL.md` skills, auto-discovered                     |
| `omp/agent/config.yml` | OMP global config under `PI_CONFIG_DIR`; agent override via `PI_CODING_AGENT_DIR` |
| `omp/agent/APPEND_SYSTEM.md` | OMP global context file |
| `omp/agent/keybindings.json` | Runtime keybinding fallback for current OMP builds |
| `omp/agent/extensions/` | OMP extensions |
| `omp/agent/tools/` | OMP custom tools |
| `pi/extensions/`      | TypeScript extensions, auto-loaded                             |
| `pi/themes/`          | Custom Pi themes, auto-discovered                              |

On first run, open `pi` and use `/login` to authenticate a provider.

#### OMP keybindings

| Key                 | Action                                         |
| ------------------- | ---------------------------------------------- |
| `Shift+Tab`         | Toggle plan mode                              |
| `Ctrl+H` / `Ctrl+L` | Cycle model roles backward/forward (`smol` > `default` > `slow` > `commit` > `thinking`) |
| `Ctrl+J` / `Ctrl+K` | Move down/up in selectors                      |
| `Ctrl+Shift+L`      | Open model selector                            |
| `Ctrl+Shift+G`      | Open Neovim reference picker                   |
| `Ctrl+G`            | Open external editor                           |
| `Ctrl+D`            | Exit                                           |

tmux passes modifier keys correctly thanks to `set -g extended-keys on` + `csi-u` in `tmux/tmux.conf`. Inside Ghostty / Kitty / iTerm2 the Kitty keyboard protocol handles this natively.

#### OMP slash commands

| Command                                         | Purpose                                                                                |
| ----------------------------------------------- | -------------------------------------------------------------------------------------- |
| `/plan`                                         | Toggle plan mode                                                                       |
| `/plan-deep`                                    | Enable plan mode and ask subagents for background planning                             |
| `/todos`                                        | Show plan progress (steps + completion state)                                          |
| `/model`                                        | Open model selector                                                                    |
| `/nvim` / `/nvim-ref`                           | Open Neovim in the current project and append file/range/code references to the prompt |
| `/login`                                        | Authenticate a provider                                                                |
| `/reload-plugins`                              | Reload plugin-discovered skills, commands, hooks, tools, agents, and MCP              |
| `/skill:<name>`                                 | Invoke a skill from `pi/skills/`                                                       |
| `/export <file>`                                | Write the session as HTML                                                              |
| `/share`                                        | Upload session as a private GitHub gist                                                |
| `/session`, `/new`, `/fork`, `/resume`, `/tree` | Session management                                                                     |


#### OMP + TanStack Intent

OMP reads project `AGENTS.md` files from the current directory upward, so repositories can provide TanStack Intent guidance in an `intent-skills` block. TanStack package skills are still loaded with Intent's CLI; they are not mirrored into OMP's native `skills/` directories.

During normal execution, use `bunx @tanstack/intent@latest list` and `bunx @tanstack/intent@latest load <package>#<skill>` when project guidance asks for matching Intent skills. During OMP plan mode, bash is filtered, so raw `bunx` is unavailable while planning. This repo configures the read-only `tanstack_intent` custom tool under `omp/agent/tools/tanstack_intent/` for plan-safe `list` and `load`; mutating Intent commands are not exposed. After adding or changing that tool in a running OMP session, run `/reload-plugins` or restart OMP.

#### Extensions

All TypeScript extensions live in `pi/extensions/` and are auto-loaded by Pi.

| Extension                    | Purpose                                                                                                                                                                                 |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `auto-commit-on-exit.ts`     | On Pi shutdown inside a git repo with uncommitted changes, prompts the user to auto-commit using the last assistant message as the subject.                                             |
| `clear.ts`                   | Adds a clear command for resetting the visible conversation.                                                                                                                            |
| `codex-ui.ts`                | Codex-oriented UI adjustments.                                                                                                                                                          |
| `file-changes.ts`            | Adds file-change command support.                                                                                                                                                       |
| `git-status.ts`              | Shows git status information in the UI.                                                                                                                                                 |
| `inline-bash.ts`             | Expands `!{command}` patterns inside user prompts before they reach the agent. Example: `current branch is !{git branch --show-current}`. Whole-line `!command` syntax is preserved.    |
| `model-thinking-footer.ts`   | Displays model thinking information in the footer.                                                                                                                                      |
| `nvim-ref.ts`                | `/nvim` or `Ctrl+Shift+G` bridge that opens Neovim in the current project; `<leader>af` tags a file, visual `<leader>ar` references a range, visual `<leader>aR` inserts selected code. |
| `pi-start-screen.ts`         | Customizes Pi's start screen.                                                                                                                                                           |
| `plan-mode.ts`               | Shift+Tab and `/plan` read-only planning mode with execute/revise/deepen approval, subagent-backed deep planning, intercom supervisor updates, RPIV `ask_user_question`/`todo`, and pi-lens tools. |
| `vim-model-thinking.ts`      | Provides direct `Ctrl+H`/`Ctrl+L` role cycling that distinguishes same-model roles by thinking level.                                                                                  |

#### Adding a skill

```bash
mkdir -p ~/.dotfiles/pi/skills/my-skill
cat > ~/.dotfiles/pi/skills/my-skill/SKILL.md <<'EOF'
---
name: my-skill
description: One-line description shown to the model
tags: [example]
---

# Skill body in markdown

Detailed instructions loaded into context only when invoked via /skill:my-skill.
EOF
```

Run `/reload` inside Pi to pick it up.

#### tmux

Pi runs cleanly inside tmux. The repo's `tmux/tmux.conf` already enables the extended-keys protocol so `Shift+Tab`, `Ctrl+Enter`, etc. reach Pi without being collapsed to plain `Enter` / `Tab`. Use `Ctrl-g` to launch the project sessionizer and start a new tmux session per project, then run `pi` inside.

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
