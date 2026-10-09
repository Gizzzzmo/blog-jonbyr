.PHONY: local serve-local site clean deploy-apex

# Port for local test builds (overridden configs point here).
LOCAL_PORT ?= 8000

# Self-contained local build: production-absolute values are overridden
# with local ones (no repo changes needed). Serve with `make serve-local`.
local:
	site-builder site -o build-local --offline \
		-D site_url=http://localhost:$(LOCAL_PORT) \
		-D media_url_template='/static/{name}'

serve-local: local
	python3 -m http.server --directory build-local $(LOCAL_PORT)

# Production build (in-place, resumable): absolute production URLs from
# site/.config.yaml; strict so warnings fail the build.
site:
	site-builder site -o build --last-build build --strict

clean:
	rm -rf build build-local

deploy-apex: site
	wrangler pages deploy build --project-name website

# todo: design deployment to personal vps
