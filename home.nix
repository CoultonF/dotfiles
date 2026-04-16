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

    # Search & Navigation
    ripgrep      # Fast grep (rg)
    fd           # Fast find
    fzf          # Fuzzy finder
    tree         # Directory tree
    lsof         # List open files/ports

    # Git
    lazygit      # Git TUI
    git          # Git CLI
    gh           # GitHub CLI
    delta        # Better git diff
    neovim-remote # nvr - open files in parent nvim from lazygit

    # Language Support
    nodejs_22    # For LSP servers
    python312    # For debugpy
    lua5_1       # For Neovim plugins

    # LSP Servers
    # Note: typescript-language-server and vscode-langservers-extracted installed via npm
    # (nodePackages was removed from nixpkgs)
    # See home.activation.npmGlobalPackages below
    pyright      # Python LSP
    lua-language-server

    # Build Tools
    gcc          # C compiler (treesitter parser compilation), includes g++
    gnumake
    # Note: tree-sitter-cli installed via npm (nixpkgs lags behind requirements)
    # See home.activation.npmGlobalPackages below
    pkg-config   # Find libraries during builds

    # Database
    postgresql   # PostgreSQL client (psql) and libpq
    libpq        # PostgreSQL C client library

    # C/C++ Libraries for Python packages
    libffi       # Foreign function interface (required by cffi, etc.)
    protobuf     # Protobuf compiler and libraries (for gcld3, etc.)

    # Cairo for SVG conversion
    cairo        # 2D graphics library
    pango        # Text rendering (often needed with cairo)

    # Terminal
    tmux
    starship

    # Docker CLI Tools
    lazydocker   # Docker TUI
    ctop         # Container metrics

    # Utilities
    openssh
    curl
    wget
    unzip
    jq           # JSON processor
    awscli2      # AWS CLI
    direnv       # Per-directory environment variables
  ] ++ lib.optionals (!isDarwin) [
    # Linux-only: locale data for containers (macOS has built-in locale support)
    glibcLocales
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
      COLORTERM = "truecolor";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      # npm global prefix (writable location outside nix store)
      NPM_CONFIG_PREFIX = "$HOME/.npm-global";
      # Help pip/Python find nix-installed libraries during compilation
      PKG_CONFIG_PATH = "$HOME/.nix-profile/lib/pkgconfig:$HOME/.nix-profile/share/pkgconfig";
      LIBRARY_PATH = "$HOME/.nix-profile/lib";
      C_INCLUDE_PATH = "$HOME/.nix-profile/include";
      CPLUS_INCLUDE_PATH = "$HOME/.nix-profile/include";
      LD_LIBRARY_PATH = "$HOME/.nix-profile/lib";
    };

    # Environment setup in .zshenv (runs for all shells including non-interactive)
    envExtra = ''
      # Source Nix profile (supports both single-user and multi-user installations)
      # Unset guard variable so nix-daemon.sh re-adds nix to PATH for this shell.
      # The parent process (e.g. bash in devcontainers) may have already sourced it,
      # setting the guard, but zsh rebuilds PATH from scratch and needs it re-sourced.
      unset __ETC_PROFILE_NIX_SOURCED
      if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      elif [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # Source home-manager session variables (PATH from sessionPath, etc.)
      # Unset guard so it re-runs — the parent process (e.g. bash in devcontainers)
      # may have already sourced it, but zsh needs the sessionPath entries re-added.
      unset __HM_SESS_VARS_SOURCED
      if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi

      # Point glibc to Nix-provided locale data (Linux containers only)
      if [[ "$OSTYPE" == "linux-gnu"* ]] && [[ -e "$HOME/.nix-profile/lib/locale/locale-archive" ]]; then
        export LOCALE_ARCHIVE="$HOME/.nix-profile/lib/locale/locale-archive"
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
      add_newline = false;
      format = "$directory$git_branch$character";
      right_format = "";
      
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
    historyLimit = 50000;
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
      # Note: fzf-tmux-url plugin replaced by ~/.dotfiles/bin/tmux-url-picker
      # (bound to prefix+u in tmux.conf) to handle URLs that wrap across lines
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
  # Direnv
  # ============================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;  # Better nix integration
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

  # Lazygit config
  xdg.configFile."lazygit/config.yml".source = ./lazygit/config.yml;

  # ============================================================================
  # Environment
  # ============================================================================
  # Note: tmux-sessionizer is already in ~/.dotfiles/bin/ which is added to PATH
  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.dotfiles/bin"
    "$HOME/.local/bin"
  ];

  # ============================================================================
  # npm global packages (for tools where nixpkgs lags behind)
  # ============================================================================
  home.activation.npmGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="${homeDirectory}/.npm-global"
    export PATH="${pkgs.nodejs_22}/bin:${homeDirectory}/.npm-global/bin:$PATH"
    mkdir -p "${homeDirectory}/.npm-global"
    for pkg in tree-sitter-cli typescript-language-server vscode-langservers-extracted; do
      if ! ${pkgs.nodejs_22}/bin/npm list -g "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg via npm..."
        ${pkgs.nodejs_22}/bin/npm install -g "$pkg" || echo "WARNING: Failed to install $pkg"
      fi
    done
  '';

  # ============================================================================
  # Note: OrbStack is used for Docker on macOS (installed separately)
  # OrbStack handles its own startup and doesn't need a launchd agent
  # ============================================================================
}
