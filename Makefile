.PHONY: build strict clean deploy

# README/flake/Makefile are repo scaffolding, not site content.
IGNORES = -i README.md -i flake.nix -i flake.lock -i Makefile -i .gitignore

build:
	site-builder . -o build $(IGNORES)

strict:
	site-builder . -o build --strict $(IGNORES)

clean:
	rm -rf build

deploy: strict
	wrangler pages deploy build --project-name website
