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
        # Bare-<lang>.so grammar dir with only the languages the site
        # highlights (cpp + arm fences). Overrides the wrapper default
        # (raw nixpkgs grammar dirs carry versioned *-X.Y.Z.so names
        # the lua filter cannot resolve); wrapper uses --set-default
        # so explicit env wins in both shell and package builds.
        siteGrammars = builder.lib.mkGrammarDir pkgs [
          pkgs.tree-sitter-grammars.tree-sitter-cpp
          builder.packages.${system}.tree-sitter-arm
        ];
      in {
        # The blog, built with the pinned site-builder. `nix build` yields
        # the deployable output directory.
        packages.blog = pkgs.stdenv.mkDerivation {
          name = "blog-jonbyr";
          src = ./.;
          dontUnpack = true;
          nativeBuildInputs = [ site-builder ];
          buildPhase = ''
            export TREESITTER_PARSERS=${siteGrammars}
            site-builder "$src/site" --output $out --offline \
              -D "current_year=$(date +%Y)"
          '';
          installPhase = "true";
        };

        packages.default = self.packages.${system}.blog;

        devShells.default = pkgs.mkShell {
          name = "blog-jonbyr-dev-shell-env";
          env.TREESITTER_PARSERS = "${siteGrammars}";
          packages = with pkgs; [
            site-builder
            python314Packages.mdformat
            python314Packages.mdformat-frontmatter
            python314Packages.mdformat-wikilink
            python314Packages.mdformat-gfm
            wrangler
            # File watcher for `make serve-local` (rebuild on source change).
            entr
          ];
        };
      }
    );
}
