# blog-jonbyr

Personal blog. Content plus templates; built with
[`site-builder`](https://github.com/Gizzzzmo/website).

## Build

```sh
nix develop
make build   # or: make strict (warnings become errors)
```

Output lands in `build/`. `make deploy` pushes it to Cloudflare Pages.

## Versioning

Publish/modified dates and per-article version history come from the
builder's ledger and git state: **commit before building** — builds on a
dirty tree render fine but record no new versions.
