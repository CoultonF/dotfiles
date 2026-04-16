# Dotfiles

Nix-based dotfiles with two setup paths:
- **Full**: `bootstrap.sh` runs Home Manager (`home.nix`)
- **Lightweight**: `devcontainer/post-install.sh` uses `nix profile install` + manual config copies

## Known issues

- **nixpkgs `tree-sitter` is outdated**. `tree-sitter-cli` is installed via npm instead. Do not replace with the nix package.
- **nvim-treesitter uses `main` branch** for nvim 0.12+ compatibility. The plugin only manages parser installation; highlighting and indentation use native `vim.treesitter` APIs via autocmd.
