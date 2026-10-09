.PHONY: build strict clean deploy

build:
	site-builder site -o build

strict:
	site-builder site -o build --strict

clean:
	rm -rf build

deploy: strict
	wrangler pages deploy build --project-name website
