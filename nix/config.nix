# Nix Package Configuration
# Install with: nix-env -iA nixpkgs.devTools
#
# This defines all development tools to be installed via Nix
# in devcontainers or on any system with Nix installed.

{
  packageOverrides = pkgs: with pkgs; {
    devTools = pkgs.buildEnv {
      name = "dev-tools";
      paths = [
        # Editor
        neovim

        # AI Coding Assistant
        opencode

        # Search & Navigation
        ripgrep      # Fast grep (rg)
        fd           # Fast find
        fzf          # Fuzzy finder
        tree         # Directory tree

        # Git
        lazygit      # Git TUI
        git          # Git CLI
        delta        # Better git diff

        # Language Support
        nodejs_22    # For LSP servers
        python312    # For debugpy
        lua5_1       # For Neovim plugins

        # LSP Servers (optional - Mason can also install these)
        nodePackages.typescript-language-server
        nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
        pyright      # Python LSP
        lua-language-server

        # Build Tools
        gcc          # C compiler (treesitter needs this)
        gnumake

        # Utilities
        curl
        wget
        unzip
        jq           # JSON processor
        xclip        # Clipboard (requires DISPLAY)
        xvfb-run     # Virtual framebuffer for headless clipboard
      ];
    };
  };
}
