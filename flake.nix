{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Supported systems
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      # Helper to generate attributes for each system
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Bun pinned to the version OMP requires (>=1.3.14), built native for the host.
      #
      # Why this exists: our local dev box is an OrbStack arm64 VM running an
      # *amd64-personality* container (uname -m = x86_64, system loader is
      # /lib64/ld-linux-x86-64.so.2; there is NO /lib/ld-linux-aarch64.so.1).
      # The `curl bun.com/install` path is fooled by the personality into
      # fetching the x64 build, which then runs under x86 emulation -- that
      # emulation is what wedges OMP's event loop (lost futex wakeups). A raw
      # prebuilt arm64 bun zip won't run either (its interpreter is missing).
      # Nix is the only thing that produces a working arm64 bun here, because it
      # autoPatchelf's the binary onto its own arm64 glibc loader in /nix/store.
      #
      # nixpkgs-unstable currently lags at bun 1.3.11 (< OMP's 1.3.14 floor), so
      # override just version + src. overrideAttrs reuses nixpkgs' known-good
      # buildInputs/autoPatchelfHook wiring -- only the source archive changes.
      # On x86_64 (AWS EC2 amd64 devpods, which DO have AVX2) we keep plain
      # nixpkgs bun; the baseline/AVX dance in the activation still guards those.
      mkBun = pkgs:
        if pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64 then
          pkgs.bun.overrideAttrs (old: rec {
            version = "1.3.14";
            src = pkgs.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-aarch64.zip";
              hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
            };
          })
        else pkgs.bun;

      # Helper to create a home configuration for a given system
      mkHomeConfig = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isDarwin = pkgs.stdenv.isDarwin;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit isDarwin;
            bunPinned = mkBun pkgs;
          };
        };
    in
    {
      homeConfigurations = {
        # Usage: home-manager switch --flake .#aarch64-darwin
        "aarch64-darwin" = mkHomeConfig "aarch64-darwin";
        "x86_64-darwin" = mkHomeConfig "x86_64-darwin";
        "x86_64-linux" = mkHomeConfig "x86_64-linux";
        "aarch64-linux" = mkHomeConfig "aarch64-linux";
      };

      # Pinned bun, per system. The lightweight (non-Home-Manager) container
      # path in devcontainer/post-install.sh consumes this via `nix build .#bun`
      # so both setup paths land the same native-arm64 bun >=1.3.14.
      packages = forAllSystems (system:
        let bun = mkBun nixpkgs.legacyPackages.${system};
        in {
          inherit bun;
          default = bun;
        }
      );

      # Development shell for working on the config
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            buildInputs = [ pkgs.home-manager ];
          };
        }
      );
    };
}
