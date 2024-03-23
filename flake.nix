{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    viacd-src = {
      url = "github:alphatechnolog/viacd";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    viacd-src,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.default = pkgs.callPackage ./default.nix {
        src = viacd-src;
      };
      devShells.default = with pkgs;
        mkShell {
          buildInputs = [zig];
        };
    });
}
