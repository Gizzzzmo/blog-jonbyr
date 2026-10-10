# blog-jonbyr

Personal blog under <https://jonbyr.com> Built by custom python builder,
currently private.

## Architecture

Any version of the blog is tied to a particular commit of this git repository.
The builder verifies that the git tree isn't dirty when building the site (see
`make site`). All older versions remain accessible under
`https://<commit>.blog.jonbyr.com`.

Large media files shared between all versions of the blog are accessible in a
content addressable storage under
`https://cdn.jonbyr.com/static/<hash>.<file-extension>`.

The website links to the repo where its own source is hosted, both the latest
version, and the commit that was used for the current version. These links go to
<https://blog-git.jonbyr.com> and
`https://blog-source.jonbyr.com/<ref>/<path/to/file>` respectively.

With the current setup all dns settings are hosted on cloudflare, the cdn
subdomain, and the apex domain point to cloudflare workers. The .blog subdomains
point to a personal VPS, and the blog-source, and blog-git subdomains are
redirects to github, where the git repo is currently hosted.
