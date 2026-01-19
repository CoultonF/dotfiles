# Global development environment shell
# This nix-shell is automatically activated when you start a new terminal
# Install Nix: https://nixos.org/download.html
# Then run: ./install.sh

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "dev-environment";

  buildInputs = with pkgs; [
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

    # Terminal Multiplexer
    zellij       # Modern tmux alternative with vim mode

    # Utilities
    curl
    wget
    unzip
    jq           # JSON processor
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    # Linux-only packages (for headless clipboard in containers)
    xclip        # Clipboard (requires DISPLAY)
    xvfb-run     # Virtual framebuffer for headless clipboard
  ];

  shellHook = ''
    # Welcome message
    echo "🚀 Nix development environment loaded"
    echo "📦 Tools available: nvim, opencode, lazygit, rg, fd, fzf, zellij, and more"
  '';
}
