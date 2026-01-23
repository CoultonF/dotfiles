{ config, pkgs, lib, isDarwin, ... }:

let
  # Get from environment, with fallback for pure evaluation
  envUser = builtins.getEnv "USER";
  envHome = builtins.getEnv "HOME";
  
  username = if envUser != "" then envUser else "cfraser";
  homeDirectory = if envHome != "" then envHome else 
    (if isDarwin then "/Users/${username}" else "/home/${username}");
in
{
  # Home Manager configuration
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.05";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ============================================================================
  # Packages
  # ============================================================================
  home.packages = with pkgs; [
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

    # LSP Servers
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
    pyright      # Python LSP
    lua-language-server

    # Build Tools
    gcc          # C compiler (treesitter needs this)
    gnumake

    # Terminal Multiplexer
    tmux

    # Docker Tools
    colima       # Container runtime for macOS
    docker-client # Docker CLI
    lazydocker   # Docker TUI
    ctop         # Container metrics

    # Utilities
    curl
    wget
    unzip
    jq           # JSON processor
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Linux-only packages (for headless clipboard in containers)
    xclip
  ];

  # ============================================================================
  # Zsh
  # ============================================================================
  programs.zsh = {
    enable = true;
    
    # Aliases
    shellAliases = {
      python = "python3";
      pip = "pip3";
      ll = "ls -alG";
      ts = "tmux-sessionizer";
      lg = "lazygit";
      v = "nvim";
    };

    # Environment variables set in .zshenv
    sessionVariables = {
      EDITOR = "nvim";
    };

    # Add to PATH
    initContent = ''
      # Add dotfiles bin to PATH
      export PATH="$HOME/.dotfiles/bin:$PATH"
      
      # pipx path
      export PATH="$PATH:$HOME/.local/bin"
      
      # Bun
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
      
      # Google Chrome alias (macOS)
      if [[ "$OSTYPE" == "darwin"* ]]; then
        alias google-chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
      fi
      
      # Auto-start tmux with default layout (skip if in IDE or already in tmux)
      if [[ "$TERM_PROGRAM" != "vscode" && -z "$INTELLIJ_ENVIRONMENT_READER" && -z "$VSCODE_PID" && -z "$VSCODE_INJECTION" ]]; then
        if command -v tmux &>/dev/null && [[ -z "$TMUX" ]]; then
          ~/.dotfiles/bin/tmux-startup
        fi
      fi
    '';

    # Completions
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # History
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };
  };

  # ============================================================================
  # Starship Prompt
  # ============================================================================
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # ============================================================================
  # tmux
  # ============================================================================
  programs.tmux = {
    enable = true;
    
    # Basic settings
    prefix = "C-a";
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 10000;
    mouse = true;
    terminal = "tmux-256color";
    
    # Extra configuration (our full config)
    extraConfig = builtins.readFile ./tmux/tmux.conf;
  };

  # ============================================================================
  # Git
  # ============================================================================
  programs.git = {
    enable = true;
    
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };

  # Delta for better diffs
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
    };
  };

  # ============================================================================
  # FZF
  # ============================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height=50%"
      "--layout=reverse"
      "--border"
    ];
  };

  # ============================================================================
  # Config Files
  # ============================================================================
  
  # Neovim config (link entire directory)
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };

  # Ghostty config
  xdg.configFile."ghostty/config".source = ./ghostty/config;

  # OpenCode config
  xdg.configFile."opencode/opencode.json".source = ./opencode/opencode.json;

  # ============================================================================
  # Environment
  # ============================================================================
  # Note: tmux-sessionizer is already in ~/.dotfiles/bin/ which is added to PATH
  home.sessionPath = [
    "$HOME/.dotfiles/bin"
    "$HOME/.local/bin"
  ];

  # ============================================================================
  # Launchd Agents (macOS)
  # ============================================================================
  launchd.agents.colima = {
    enable = true;
    config = {
      Label = "com.github.colima";
      ProgramArguments = [ "${pkgs.colima}/bin/colima" "start" "--foreground" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/colima.log";
      StandardErrorPath = "/tmp/colima.error.log";
    };
  };
}
