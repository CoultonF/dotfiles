{ config, pkgs, lib, isDarwin, ... }:

let
  # Get from environment, with fallback for pure evaluation
  envUser = builtins.getEnv "USER";
  envHome = builtins.getEnv "HOME";
  envDotfilesDir = builtins.getEnv "DOTFILES_DIR";
  envPwd = builtins.getEnv "PWD";
  
  username = if envUser != "" then envUser else "cfraser";
  homeDirectory = if envHome != "" then envHome else
    (if isDarwin then "/Users/${username}" else "/home/${username}");
  dotfilesDirectory =
    if envDotfilesDir != "" then envDotfilesDir
    else if envPwd != "" then envPwd
    else "${homeDirectory}/dotfiles";
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
    opencode

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
    bun          # JS runtime / package manager (used for Codex install)
    python312    # For debugpy
    lua5_1       # For Neovim plugins
    cargo        # Rust package manager

    # LSP Servers
    # Note: vtsls, basedpyright, and vscode-langservers-extracted installed via bun
    # (nodePackages was removed from nixpkgs)
    # See home.activation.bunGlobalPackages below
    ruff         # Python LSP, linter, formatter
    lua-language-server
    postgres-language-server  # SQL LSP for Postgres (binary: postgrestools)

    # Linters & Formatters (conform.nvim + nvim-lint; deterministic via nix)
    stylua           # Lua formatter
    sqlfluff         # SQL lint + format (postgres dialect)
    hadolint         # Dockerfile linter
    shellcheck       # Shell linter
    yamllint         # YAML linter
    markdownlint-cli # Markdown linter (binary: markdownlint)

    # Build Tools
    gcc          # C compiler (treesitter parser compilation), includes g++
    gnumake
    # Note: tree-sitter-cli installed via bun (nixpkgs lags behind requirements)
    # See home.activation.bunGlobalPackages below
    pkg-config   # Find libraries during builds

    # Database
    postgresql   # PostgreSQL client (psql) and libpq
    libpq        # PostgreSQL C client library
    rainfrog     # PostgreSQL TUI (browse/run queries; <leader>D in nvim)

    # C/C++ Libraries for Python packages
    libffi       # Foreign function interface (required by cffi, etc.)

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
    open-policy-agent # OPA policy engine (opa)
  ] ++ lib.optionals (!isDarwin) [
    chromium     # Native browser for Puppeteer in Linux containers
    glibcLocales # Locale data for containers (macOS has built-in locale support)
    bubblewrap   # Sandbox utility required by Codex on Linux
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
      PI_CONFIG_DIR = "dotfiles/omp";
      PI_CODING_AGENT_DIR = "${homeDirectory}/dotfiles/omp/agent";
      EDITOR = "nvim";
      COLORTERM = "truecolor";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      # Help pip/Python find nix-installed libraries during compilation
      PKG_CONFIG_PATH = "$HOME/.nix-profile/lib/pkgconfig:$HOME/.nix-profile/share/pkgconfig";
      LIBRARY_PATH = "$HOME/.nix-profile/lib";
      C_INCLUDE_PATH = "$HOME/.nix-profile/include";
      CPLUS_INCLUDE_PATH = "$HOME/.nix-profile/include";
      LD_LIBRARY_PATH = "$HOME/.nix-profile/lib";
      OPENCODE_DISABLE_CLAUDE_CODE = "1";
      OPENCODE_DISABLE_CLAUDE_CODE_PROMPT = "1";
      OPENCODE_DISABLE_CLAUDE_CODE_SKILLS = "1";
      PI_OAUTH_CALLBACK_HOST = "0.0.0.0";
      PI_FORCE_IMAGE_PROTOCOL = "kitty";
    } // lib.optionalAttrs (!isDarwin) {
      PUPPETEER_EXECUTABLE_PATH = "$HOME/.nix-profile/bin/chromium";
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

      # Keep OMP paths available even when this shell inherits Home Manager's
      # zsh session guard from a parent shell. That guard can skip the generated
      # sessionVariables block after `exec zsh`, so export these load-bearing
      # variables outside the guard as well.
      export PI_CONFIG_DIR="dotfiles/omp"
      export PI_CODING_AGENT_DIR="$HOME/$PI_CONFIG_DIR/agent"
      export PI_FORCE_IMAGE_PROTOCOL="kitty"
      if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        export PUPPETEER_EXECUTABLE_PATH="$HOME/.nix-profile/bin/chromium"
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

      # npm global installs must not target the immutable Nix node prefix.
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
      
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

  # OpenCode config
  xdg.configFile."opencode" = {
    source = ./opencode;
    recursive = true;
  };

  # Codex CLI config
  # Keep this out of the Nix store so the CLI can persist model changes.
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/codex/config.toml";

  # Oracle config
  # Keep this out of the Nix store so Oracle sees dotfiles updates immediately.
  home.file.".oracle/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/oracle/config.json";

  # Pi coding agent config
  # Keep this out of the Nix store so Pi sees dotfiles updates immediately.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/settings.json";
  home.file.".pi/agent/APPEND_SYSTEM.md".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/APPEND_SYSTEM.md";
  home.file.".pi/agent/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/keybindings.json";
  home.file.".pi/agent/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/mcp.json";
  home.file.".pi/agent/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/skills";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/extensions";
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/pi/themes";

  # Claude Code global user instructions
  # Keep out of the Nix store so edits take effect without a Home Manager rebuild.
  home.file.".CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/.dotfiles/claude/CLAUDE.md";

  # Keep npm global installs out of the immutable Nix store.
  home.file.".npmrc".text = ''
    prefix=${homeDirectory}/.npm-global
  '';

  # ============================================================================
  # Environment
  # ============================================================================
  # Note: tmux-sessionizer is already in ~/.dotfiles/bin/ which is added to PATH
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.dotfiles/bin"
    "$HOME/.local/bin"
  ];

  # ============================================================================
  # bun global packages (for npm registry CLIs where nixpkgs lags behind)
  # ============================================================================
  home.activation.bunGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export BUN_INSTALL="${homeDirectory}/.bun"
    export PATH="${homeDirectory}/.bun/bin:${pkgs.bun}/bin:${pkgs.nodejs_22}/bin:${pkgs.unzip}/bin:$PATH"
    mkdir -p "${homeDirectory}/.bun/bin"

    bun_bin="${homeDirectory}/.bun/bin/bun"

    # Bun's installer selects x64-baseline on Linux x86_64 CPUs without AVX2.
    if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ] && ! grep -qi avx2 /proc/cpuinfo; then
      echo "Installing Bun x64-baseline build for CPU without AVX2..."
      ${pkgs.curl}/bin/curl -fsSL https://bun.com/install | ${pkgs.bash}/bin/bash || true
    elif [ -x "$bun_bin" ]; then
      "$bun_bin" upgrade || true
    else
      ${pkgs.curl}/bin/curl -fsSL https://bun.com/install | ${pkgs.bash}/bin/bash || true
    fi

    set_omp_native_target() {
      case "$(uname -s):$(uname -m)" in
        Linux:x86_64)
          omp_native_platform="linux-x64"
          ;;
        Darwin:x86_64)
          omp_native_platform="darwin-x64"
          ;;
        *)
          return 1
          ;;
      esac

      if [ "''${PI_NATIVE_VARIANT:-}" = "modern" ] || [ "''${PI_NATIVE_VARIANT:-}" = "baseline" ]; then
        omp_native_variant="$PI_NATIVE_VARIANT"
      elif [ "$omp_native_platform" = "linux-x64" ]; then
        if grep -qi avx2 /proc/cpuinfo 2>/dev/null; then
          omp_native_variant="modern"
        else
          omp_native_variant="baseline"
        fi
      elif { sysctl -n machdep.cpu.leaf7_features 2>/dev/null | grep -qi avx2; } || { sysctl -n machdep.cpu.features 2>/dev/null | grep -qi avx2; }; then
        omp_native_variant="modern"
      else
        omp_native_variant="baseline"
      fi

      omp_native_file="pi_natives.$omp_native_platform-$omp_native_variant.node"
    }

    ensure_omp_native_staged() {
      set_omp_native_target || return 0
      native_dir="${homeDirectory}/.bun/install/global/node_modules/@oh-my-pi/pi-natives/native"
      leaf_dir="${homeDirectory}/.bun/install/global/node_modules/@oh-my-pi/pi-natives-$omp_native_platform"
      native_path="$native_dir/$omp_native_file"
      leaf_path="$leaf_dir/$omp_native_file"

      # The loader probes @oh-my-pi/pi-natives/native, not the platform leaf package.
      # Treat the leaf package as a staging source only.

      if [ -f "$native_path" ]; then
        return 0
      fi

      if [ ! -f "$leaf_path" ]; then
        return 1
      fi

      mkdir -p "$native_dir" && rm -f "$native_path" && cp -f "$leaf_path" "$native_path"
    }

    install_omp_with_native() {
      set_omp_native_target || return 0
      echo "Installing OMP native addon for $omp_native_platform..."
      if "${homeDirectory}/.bun/bin/bun" add -g "$1" @oh-my-pi/pi-natives "@oh-my-pi/pi-natives-$omp_native_platform"; then
        ensure_omp_native_staged || echo "WARNING: Failed to stage OMP native addon"
      else
        echo "WARNING: Failed to install OMP native addon"
      fi
    }

    install_bun_global() {
      pkg="$1"
      bin="$2"
      if [ "$bin" = "omp" ] && set_omp_native_target; then
        install_omp_with_native "$pkg"
      elif [ ! -x "${homeDirectory}/.bun/bin/$bin" ]; then
        echo "Installing $pkg via bun..."
        "${homeDirectory}/.bun/bin/bun" add -g "$pkg" || echo "WARNING: Failed to install $pkg"
      fi
    }

    if [ -x "$bun_bin" ]; then
      install_bun_global tree-sitter-cli tree-sitter
      install_bun_global basedpyright basedpyright-langserver
      install_bun_global typescript-language-server typescript-language-server
      install_bun_global vscode-langservers-extracted vscode-json-language-server
      install_bun_global @steipete/oracle oracle
      install_bun_global @openai/codex codex
      install_bun_global @earendil-works/pi-coding-agent pi
      install_bun_global @oh-my-pi/pi-coding-agent omp
      install_bun_global @termdraw/app termdraw
      install_bun_global oxlint oxlint
      install_bun_global oxfmt oxfmt
      install_bun_global @vtsls/language-server vtsls
    else
      echo "WARNING: $bun_bin not found; skipping bun-managed global CLIs"
    fi
  '';

  # ============================================================================
  # Note: OrbStack is used for Docker on macOS (installed separately)
  # OrbStack handles its own startup and doesn't need a launchd agent
  # ============================================================================
}
