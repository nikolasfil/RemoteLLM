# Nginx Reverse Proxy

`nginx` is the single browser entry point for the stack. It binds to a local port and routes traffic to code-server, web-terminal, and LiteLLM, exposing them all from one address.

## Features

- Single local port for all browser-accessible services
- WebSocket upgrade support for code-server and ttyd
- LiteLLM admin UI accessible at a stable sub-path
- Static landing page at `${BASE_PATH}/` (root `/` when `BASE_PATH` is empty)
- Configurable bind address (`NGINX_BIND`) and port (`NGINX_PORT`)
- Optional basic-auth gate for Hermes dashboard when exposed on LAN
- Read-only container with `no-new-privileges`

## Functionalities

### Paths and Upstreams

All paths below are relative to `BASE_PATH` (empty by default, so they start at `/`).

| Path | Upstream | Notes |
|---|---|---|
| `${BASE_PATH}/` | static HTML | Landing page (`config/nginx/html/index.html`) |
| `${BASE_PATH}/code/` | `code-server:8080` | Browser IDE; WebSocket required |
| `${BASE_PATH}/terminal/` | `web-terminal:7681` | Browser terminal; WebSocket required |
| `${BASE_PATH}/api/litellm/` | `litellm:4000` | LiteLLM API and UI |
| `${BASE_PATH}/api/litellm/ui` | `litellm:4000` | Admin dashboard |
| `${BASE_PATH}/docs/` | static HTML | Rendered `docs/` (architecture, setup, guides); built with `make docs` |

The terminal path preserves the full request URI so ttyd sub-paths reach ttyd correctly. Code-server has both the `BASE_PATH` and the `/code/` prefix stripped before proxying, so code-server itself is prefix-agnostic.

### Bind Address and Port

```dotenv
NGINX_BIND=127.0.0.1   # default: local-only
NGINX_PORT=8088         # default port
```

Change `NGINX_BIND=0.0.0.0` to expose the stack on the LAN. When you do this, replace all placeholder passwords first and run `make security-review`.

### Reloading Config

After editing `config/nginx/templates/default.conf.template`:

```sh
docker compose restart nginx
```

### Rendered Docs Site

`${BASE_PATH}/docs/` serves a static HTML mirror of `docs/` (everything except `docs/dev/` and
`docs/presentations/`), styled like the landing page and rendered with `pandoc`. It is a build
artifact under `config/nginx/html/docs/` (git-ignored) and is not regenerated automatically —
run this after cloning and after any edit to a doc file:

```sh
make docs
```

`scripts/build-docs.sh` converts `docs/*.md` and `docs/guides/*.md`, rewrites cross-doc `.md`
links to `.html`, and generates a shared sidebar. Requires `pandoc` on the host (not inside a
container).

### Deploying Behind Another Nginx

Set `BASE_PATH=/remotellm` (or any path prefix) in `.env` before starting the stack. The
nginx config is rendered from a template at startup, so every `location` block, redirect,
LiteLLM `SERVER_ROOT_PATH`, and ttyd base-path are automatically prefixed. Leave `BASE_PATH=`
empty (the default) for a root deployment — behaviour is identical to before.

The outer nginx only needs a plain pass-through; **do not strip the prefix**. Add this
inside the `server { }` block of your outer nginx that listens on port 80:

```nginx
# Redirect /remotellm (no trailing slash) so browsers land on /remotellm/
location = /remotellm {
    return 301 /remotellm/;
}

# Pass all /remotellm/ traffic to the RemoteLLM stack.
# Do NOT rewrite or strip the prefix — the inner nginx handles routing.
location /remotellm/ {
    proxy_pass http://127.0.0.1:8088;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;
}
```

Replace `127.0.0.1:8088` with the actual `NGINX_BIND:NGINX_PORT` from your `.env` if you
changed the defaults. The `proxy_read_timeout` / `proxy_send_timeout` values match the inner
nginx and are required to keep code-server and terminal WebSocket connections alive.

The inner stack receives the full `/remotellm/…` path and routes it correctly. The
`code-server` location is the one exception: the inner nginx strips both the `BASE_PATH` and
the `/code/` prefix before forwarding to code-server, so code-server itself stays
prefix-agnostic.

After changing `BASE_PATH`, restart nginx to apply the re-rendered config:

```sh
docker compose restart nginx
```

### Checking Logs

```sh
docker compose logs nginx --tail=100
```

## Limitations

- No TLS termination by default. Use `http://`, not `https://`, unless you add TLS to nginx.
- WebSocket connections for the terminal depend on nginx preserving the full URI path. Non-standard proxy configurations that rewrite or strip the path will break the terminal.
- Sub-path deployment is supported via `BASE_PATH`. The LiteLLM admin UI may still emit some root-absolute `/ui/…` asset requests (an upstream limitation); the API and all other services work fully under any prefix.
- `client_max_body_size` is set to 100 MB. Uploads larger than this will fail with a 413.

## Hardware Requirements

| Metric | Value |
|---|---|
| RAM (idle) | 16 MB |
| RAM (peak) | 64 MB |
| CPU | <0.1 cores idle, 0.2 cores peak |

Nginx has negligible resource requirements. It is always part of the core stack.
