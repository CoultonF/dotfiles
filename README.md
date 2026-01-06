# Dotfiles

Personal development environment configuration for Neovim + OpenCode + Ghostty.

Designed to work both locally on macOS and inside Docker devcontainers via Nix.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles

# Run the installer
cd ~/.dotfiles && ./install.sh
```

## What's Included

| Component | Description |
|-----------|-------------|
| **Ghostty** | GPU-accelerated terminal with Catppuccin theme |
| **Neovim** | Full IDE setup with LSP, completion, debugging |
| **OpenCode** | AI coding assistant integration |
| **Nix** | Declarative package management for devcontainers |

## Directory Structure

```
~/.dotfiles/
├── README.md              # This file
├── install.sh             # Bootstrap script
├── ghostty/
│   └── config             # Ghostty terminal config
├── nvim/
│   ├── init.lua           # Neovim entry point
│   └── lua/
│       ├── config/        # Core settings
│       │   ├── options.lua
│       │   ├── keymaps.lua
│       │   ├── autocmds.lua
│       │   └── lazy.lua
│       └── plugins/       # Plugin configurations
│           ├── opencode.lua
│           ├── telescope.lua
│           ├── harpoon.lua
│           ├── lsp.lua
│           ├── debug.lua
│           └── ...
├── nix/
│   └── config.nix         # Nix packages
└── devcontainer/
    ├── mounts.json        # Devcontainer mount config
    ├── docker-compose-volumes.yml
    └── post-install.sh    # Container setup script
```

## Keybindings Reference

Leader key: `<Space>`

### Navigation

| Key | Action |
|-----|--------|
| `ff` or `<leader><leader>` | Find files |
| `gf` or `<leader>sg` | Live grep |
| `<leader>,` | Switch buffer |
| `<leader>x` or `-` | File explorer (Oil) |
| `<C-h>` / `<C-l>` | Previous/next buffer |
| `<C-d>` / `<C-u>` | Scroll down/up (centered) |
| `K` / `J` | Move 5 lines up/down (centered) |

### Harpoon (Quick File Access)

| Key | Action |
|-----|--------|
| `<leader>a` | Add file to harpoon |
| `<leader>H` | Open harpoon menu |
| `<leader>1-5` | Jump to harpoon file 1-5 |
| `[h` / `]h` | Previous/next harpoon file |

### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | Go to references |
| `gi` | Go to implementation |
| `gh` | Hover documentation |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>fm` | Format buffer |

### Git

| Key | Action |
|-----|--------|
| `<leader>gg` | Open LazyGit |
| `<leader>gd` | Diff this |
| `<leader>gD` | Diff this ~ |
| `<leader>gs` | Stage hunk |
| `<leader>gr` | Reset hunk |
| `<leader>gb` | Blame line |
| `<leader>gB` | Toggle line blame |
| `<leader>gc` | Git branches (Telescope) |

### Debugging

| Key | Action |
|-----|--------|
| `<leader>dd` | Toggle DAP UI |
| `<leader>da` | Start/Continue |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dD` | Clear all breakpoints |
| `<leader>ds` | Step over |
| `<leader>di` | Step into |
| `<leader>do` | Step out |
| `<leader>dx` | Terminate |

### Testing

| Key | Action |
|-----|--------|
| `<leader>tt` | Test summary |
| `<leader>tr` | Run nearest test |
| `<leader>tf` | Run file tests |
| `<leader>ta` | Run all tests |
| `<leader>td` | Debug nearest test |

### OpenCode (AI)

| Key | Mode | Action |
|-----|------|--------|
| `<leader>oa` | Normal | Ask OpenCode |
| `<leader>oa` | Visual | Ask about selection |
| `<leader>os` | Normal | Select action |
| `<leader>oc` | Normal | Run command |

### Other

| Key | Action |
|-----|--------|
| `<leader>zz` | Zen mode |
| `<leader>f` | Toggle fold |
| `<leader>j` | Join lines |
| `<leader>s` | Search/replace word under cursor |
| `<C-t>` | Toggle terminal |
| `<C-q>` | Close buffer |

## Devcontainer Setup

### 1. Add mounts to `devcontainer.json`

```json
{
  "mounts": [
    "source=${localEnv:HOME}${localEnv:USERPROFILE}/.config-docker/nvim,target=/root/.config/nvim,type=bind",
    "source=${localEnv:HOME}${localEnv:USERPROFILE}/.local-docker/share/nvim,target=/root/.local/share/nvim,type=bind",
    "source=${localEnv:HOME}${localEnv:USERPROFILE}/.config-docker/nix,target=/root/.config/nixpkgs,type=bind"
  ]
}
```

### 2. Add volumes to `docker-compose.dev.yml`

```yaml
services:
  your-service:
    volumes:
      # Neovim config and data
      - ${HOME}/.config-docker/nvim:/root/.config/nvim:cached
      - ${HOME}/.local-docker/share/nvim:/root/.local/share/nvim:cached
      # Nix config
      - ${HOME}/.config-docker/nix:/root/.config/nixpkgs:cached
```

### 3. Add Nix to `Dockerfile.dev`

```dockerfile
# Install Nix package manager
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
ENV PATH="/root/.nix-profile/bin:$PATH"
```

### 4. Install packages (in container)

```bash
# Using config.nix (recommended)
nix-env -iA nixpkgs.devTools

# Or manually
nix-env -iA nixpkgs.neovim nixpkgs.opencode nixpkgs.lazygit nixpkgs.ripgrep nixpkgs.fd
```

## Workflow

### Local Development (Mac)

1. Open Ghostty
2. Navigate to project: `cd ~/Projects/myproject`
3. Start OpenCode: `opencode &`
4. Edit with Neovim: `nvim .`
5. Use `<leader>oa` to ask OpenCode questions

### Devcontainer Development

1. Open Ghostty
2. Enter container: `docker exec -it mycontainer bash`
3. Start OpenCode: `opencode &`
4. Edit with Neovim: `nvim .`
5. Use `<leader>oa` to ask OpenCode questions

## Plugins Included

| Plugin | Purpose |
|--------|---------|
| lazy.nvim | Plugin manager |
| catppuccin | Colorscheme |
| telescope.nvim | Fuzzy finder |
| harpoon | Quick file navigation |
| oil.nvim | File explorer |
| nvim-lspconfig | LSP support |
| mason.nvim | LSP/DAP installer |
| nvim-cmp | Autocompletion |
| nvim-treesitter | Syntax highlighting |
| nvim-dap | Debugging |
| neotest | Test runner |
| lazygit.nvim | Git TUI |
| gitsigns.nvim | Git integration |
| lualine.nvim | Status line |
| which-key.nvim | Key hints |
| toggleterm.nvim | Terminal |
| opencode.nvim | AI assistant |
| zen-mode.nvim | Distraction-free |
| Comment.nvim | Easy commenting |
| nvim-surround | Surround text |
| todo-comments.nvim | TODO highlighting |

## Troubleshooting

### Neovim plugins not loading

```bash
# In Neovim, run:
:Lazy sync
```

### LSP servers not working

```bash
# In Neovim, run:
:Mason
# Then install servers manually or:
:MasonInstallAll
```

### Nix packages not found

```bash
# Update Nix channel
nix-channel --update

# Reinstall packages
nix-env -iA nixpkgs.devTools
```

### OpenCode not connecting

Make sure OpenCode is running in the same directory:

```bash
# Start OpenCode first
opencode &

# Then open Neovim
nvim .
```

## Updating

```bash
cd ~/.dotfiles
git pull
./install.sh
```

In Neovim:
```
:Lazy sync
:MasonUpdate
:TSUpdate
```

## License

MIT
