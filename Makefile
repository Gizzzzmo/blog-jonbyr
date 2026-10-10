.PHONY: local serve-local site clean deploy deploy-blog deploy-cdn

# Port for local test builds (overridden configs point here).
LOCAL_PORT ?= 8000

# Self-contained local build: production-absolute values are overridden
# with local ones (no repo changes needed). Serve with `make serve-local`.
# live_reload injects the auto-reload snippet (see templates); __version
# is written last so reloads always fetch post-build HTML. A failed build
# stops make before the sentinel flips, so broken builds never reload.
local:
	site-builder site -o build-local --offline \
		-D site_url=http://localhost:$(LOCAL_PORT) \
		-D media_url_template='/static/{name}' \
		-D live_reload=true
	date +%s%N > build-local/__version

# Serve the local build and rebuild on source change (Ctrl-C stops
# both server and watcher). Watches site/ + this Makefile only: never
# build-local/ (rebuild output would retrigger itself) and never flake.nix
# (changing it requires restarting nix develop anyway). entr exits 2 when
# the directory listing changes (new/deleted files), so the loop rescans;
# any other exit (errors, signals) stops the watcher. A failed rebuild
# never stops the loop; the server keeps serving the last good build.
serve-local: local
	python3 -m http.server --directory build-local $(LOCAL_PORT) & \
	server=$$!; \
	trap 'kill $$server' EXIT INT TERM; \
	for i in 1 2 3 4 5 6 7 8 9 10; do \
		python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:$(LOCAL_PORT)', timeout=1)" 2>/dev/null && break; \
		sleep 0.5; \
	done; \
	python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:$(LOCAL_PORT)', timeout=1)" 2>/dev/null || exit 1; \
	while true; do \
		find site Makefile -type f | entr -dn -s 'make -s local'; \
		test $$? -eq 2 || break; \
	done

# Production build (in-place, resumable): absolute production URLs from
# site/.config.yaml; strict so warnings fail the build. Media defaults
# cover the rest (last + output both build/static).
site:
	site-builder site -o build  --strict \
		--last-ledger build/.site_versions.json \
		--last-media-dir build-cdn/static \
		--media-output-dir build-cdn/static

clean:
	rm -rf build build-cdn build-local

deploy-blog: site
	wrangler deploy --config wrangler.blog.jsonc

deploy-cdn: site
	wrangler deploy --config wrangler.cdn.jsonc

deploy: deploy-blog deploy-cdn

# todo: design deployment to personal vps
