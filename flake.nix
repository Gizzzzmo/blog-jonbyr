{
  description = "blog-jonbyr: personal blog, built with site-builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    builder.url = "github:Gizzzzmo/website";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    builder,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        site-builder = builder.packages.${system}.site-builder;
      in {
        # The blog, built with the pinned site-builder. `nix build` yields
        # the deployable output directory.
        packages.blog = pkgs.stdenv.mkDerivation {
          name = "blog-jonbyr";
          src = ./.;
          dontUnpack = true;
          nativeBuildInputs = [ site-builder ];
          buildPhase = ''
            site-builder "$src" --output $out --offline \
              -i README.md -i flake.nix -i flake.lock -i Makefile -i .gitignore
          '';
          installPhase = "true";
        };

        packages.default = self.packages.${system}.blog;

        devShells.default = pkgs.mkShell {
          name = "blog-jonbyr-dev-shell";
          packages = [
            site-builder
            pkgs.wrangler
          ];
        };
      }
    );
}
