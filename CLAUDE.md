# Dotfiles

Nix-based dotfiles with two setup paths:
- **Full**: `bootstrap.sh` runs Home Manager (`home.nix`)
- **Lightweight**: `devcontainer/post-install.sh` uses `nix profile install` + manual config copies

## Known issues

- **nixpkgs `tree-sitter` is outdated** (0.25.x vs latest 0.26.x). Newer grammars may require 0.26.x features. `tree-sitter-cli` is installed via npm instead. Do not replace with the nix package.
