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
  # Packages (same for macOS and Linux, except GUI apps)
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

    # Terminal
    tmux
    starship

    # Docker CLI Tools
    lazydocker   # Docker TUI
    ctop         # Container metrics

    # Utilities
    curl
    wget
    unzip
    jq           # JSON processor
    awscli2      # AWS CLI
  ] ++ lib.optionals isDarwin [
    # macOS-only: GUI apps and tools that need OrbStack
    docker-client # Docker CLI (OrbStack provides daemon)
    devpod       # Dev environment manager (CLI)
    devpod-desktop # Dev environment manager (GUI)
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

    # Environment setup in .zshenv (runs for all shells including non-interactive)
    envExtra = ''
      # Source Nix profile (supports both single-user and multi-user installations)
      if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      elif [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';

    # Add to PATH (runs in .zshrc for interactive shells)
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
  # Starship Prompt (minimal for mobile)
  # ============================================================================
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$directory$git_branch$character";
      
      directory = {
        truncation_length = 2;
        truncate_to_repo = true;
        style = "bold cyan";
      };
      
      git_branch = {
        format = "[$branch]($style) ";
        style = "bold purple";
      };
      
      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };
      
      # Disable verbose modules
      aws.disabled = true;
      nodejs.disabled = true;
      python.disabled = true;
      package.disabled = true;
      cmd_duration.disabled = true;
      username.disabled = true;
      hostname.disabled = true;
    };
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
    
    # Plugins
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          # Save/restore sessions
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          # Auto-save every 15 minutes
          set -g @continuum-save-interval '15'
          # Auto-restore on tmux start
          set -g @continuum-restore 'on'
        '';
      }
    ];
    
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
  # Note: OrbStack is used for Docker on macOS (installed separately)
  # OrbStack handles its own startup and doesn't need a launchd agent
  # ============================================================================
}
