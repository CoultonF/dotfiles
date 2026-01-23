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
