# Website indexing policy

`daylex-site.caddy` is the versioned `/etc/caddy/sites-enabled/daylex.caddy` configuration.
It is imported by the backend's Caddyfile and survives both backend configuration renders and signed website/PWA releases.

All website routes, assets, downloads, errors and the www redirect declare `X-Robots-Tag: noindex, nofollow, nosnippet, noimageindex`. HTML entry points also include the matching robots meta tag.
Do not add `Disallow: /` to robots.txt: crawlers must retrieve a URL to discover noindex and remove an existing result.
This is search-engine exclusion, not access control; the website and downloads intentionally remain publicly accessible.

When changing the server configuration, back up the existing site file, install the candidate, validate the full `/etc/caddy/Caddyfile`, then reload Caddy. Restore the backup if validation or reload fails. Check response headers on `/`, `/assistenza.html`, `/tecnica.html`, `/app/`, `/app/installa.html`, a download, a missing route and `https://www.daylex.it/`.
