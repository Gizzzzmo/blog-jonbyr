{
  description = "blog-jonbyr: personal blog, built with site-builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    builder.url = "git+ssh://git@github.com/Gizzzzmo/website.git";
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
            site-builder "$src/site" --output $out --offline \
              -D "current_year=$(date +%Y)"
          '';
          installPhase = "true";
        };

        packages.default = self.packages.${system}.blog;

        devShells.default = pkgs.mkShell {
          name = "blog-jonbyr-dev-shell";
          packages = with pkgs; [
            site-builder
            python313Packages.mdformat
            python313Packages.mdformat-frontmatter
            python313Packages.mdformat-wikilink
            python313Packages.mdformat-gfm
            wrangler
            # File watcher for `make serve-local` (rebuild on source change).
            entr
          ];
        };
      }
    );
}
