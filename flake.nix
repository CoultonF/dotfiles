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
      
      # Get username and home directory from environment or default
      username = builtins.getEnv "USER";
      homeDirectory = builtins.getEnv "HOME";
    in
    {
      homeConfigurations = {
        # Default configuration - works on any system
        # Usage: home-manager switch --flake .#default
        "default" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin; # Apple Silicon Mac
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit username homeDirectory;
          };
        };

        # Intel Mac
        "x86_64-darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-darwin;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit username homeDirectory;
          };
        };

        # Apple Silicon Mac (M1/M2/M3)
        "aarch64-darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit username homeDirectory;
          };
        };

        # Linux x86_64
        "x86_64-linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit username homeDirectory;
          };
        };

        # Linux ARM64 (containers on Apple Silicon)
        "aarch64-linux" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.aarch64-linux;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit username homeDirectory;
          };
        };
      };

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
