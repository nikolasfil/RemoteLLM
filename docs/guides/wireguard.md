# WireGuard & VPN Proxy

Two services work together to provide private model access: `wireguard` owns the VPN tunnel, and `vpn-proxy` exposes a SOCKS5 endpoint on the internal Docker network so LiteLLM can reach a remote Ollama instance without putting the host machine on the VPN.

These services are entirely optional and are in the `vpn` Compose profile, not started by the default stack. They only matter if you want to route LiteLLM's Ollama calls to an instance that is not directly reachable — for example, one you host yourself on another machine, reachable only through your own WireGuard server. If you don't use Ollama, or your Ollama instance is already reachable without a tunnel, you can ignore this guide entirely.

## Features

- Full WireGuard VPN tunnel inside a container — host never joins the VPN
- SOCKS5 proxy (`wireguard:1080`) reachable only from services on the `remotellm` Docker network
- DNS-over-SOCKS (`socks5h`) so hostnames that resolve only inside the VPN work correctly
- TCP port forward from `wireguard:11434` → remote Ollama (via socat inside `vpn-proxy`)
- Automatic restart on failure
- Health check: `wg show` confirming the tunnel is up

## Services

### `wireguard`

LinuxServer WireGuard image. Manages the kernel WireGuard module and interface.

- Reads client config from `.local/volumes/wireguard/wg_confs/wg0.conf`
- Requires `NET_ADMIN` capability and the `/dev/net/tun` device
- Runs on Docker's default runtime (incompatible with gVisor because WireGuard needs a real kernel network namespace)
- Does not publish any host ports

### `vpn-proxy`

Shares `wireguard`'s network namespace (`network_mode: service:wireguard`). Runs two processes:

- `microsocks` on port 1080 — SOCKS5 proxy for arbitrary TCP through the VPN
- `socat` forwarding `wireguard:11434` → `OLLAMA_FORWARD_TARGET` — lets LiteLLM use `http://wireguard:11434` as a plain HTTP URL rather than a SOCKS proxy URL

The image is built from `docker/vpn-proxy/Dockerfile` using microsocks from source.

## Functionalities

### Setting Up the WireGuard Config

Place a standard WireGuard client config at:

```text
.local/volumes/wireguard/wg_confs/wg0.conf
```

Permissions must be `0600`:

```sh
chmod 600 .local/volumes/wireguard/wg_confs/wg0.conf
```

Automated copy from `.env`:

```dotenv
WIREGUARD_SOURCE=/path/to/wireguard.conf
COPY_WIREGUARD_CONFIG=1
```

Then run `make wireguard-config` or `make init`.

### Starting Manually

The default stack leaves the VPN off. Start it explicitly when needed:

```sh
make up-vpn
```

Stop only the VPN services with:

```sh
make down-vpn
```

### Network Flow

Only LiteLLM uses the VPN path. All other services (agent, code-server, npm, pip, Git) use direct internet.

```dotenv
OLLAMA_PROXY=socks5h://wireguard:1080
NO_PROXY=localhost,127.0.0.1,agent,nginx,code-server,litellm,wireguard
```

The `socks5h` scheme ensures DNS resolution happens inside the tunnel (required when the Ollama hostname is not resolvable on the host network).

### Pointing at Your Own Remote Ollama

Once the tunnel is up, tell `vpn-proxy` where your Ollama instance lives on the other end of
the VPN, and point LiteLLM at the proxy instead of a direct URL:

```dotenv
# Ollama's address as seen from inside your WireGuard server's network.
OLLAMA_FORWARD_TARGET=10.5.5.5:11434
OLLAMA_FORWARD_PORT=11434

# LiteLLM talks to the forward instead of a direct address.
OLLAMA_BASE_URL=http://wireguard:11434
```

Restart the VPN services and LiteLLM after changing either value:

```sh
docker compose up -d --force-recreate wireguard vpn-proxy
make restart-litellm
```

### Verifying the Tunnel

```sh
docker compose exec wireguard wg show
make test-vpn
```

`wg show` confirms the tunnel interface and latest handshake. `make test-vpn` sends a request to `OLLAMA_BASE_URL` through LiteLLM to confirm end-to-end connectivity.

### Checking Logs

```sh
docker compose logs wireguard --tail=100
docker compose logs vpn-proxy --tail=100
```

### Self-Hosting a WireGuard Server

RemoteLLM's `wireguard` service is a **client** — it connects to a WireGuard server you
already have. If you don't have one yet and want to reach your own Ollama instance
privately (e.g. a home server or a second machine on another network), you need a
WireGuard server on that side of the connection. This is standard WireGuard setup,
not specific to RemoteLLM:

- A small VPS or the machine running Ollama itself can act as the server. Tools like
  [`wg-easy`](https://github.com/wg-easy/wg-easy) or the upstream
  [`wireguard-install`](https://github.com/angristan/wireguard-install) script automate
  generating server and client configs.
- Add a peer for RemoteLLM and download its generated client config — that's the file
  `WIREGUARD_SOURCE` points at (see "Setting Up the WireGuard Config" above).
- Make sure the server's firewall allows the Ollama port from the WireGuard subnet, and
  use that subnet address (not a public one) as `OLLAMA_FORWARD_TARGET`.

Only client mode is supported by this stack today; running the VPN server itself
inside RemoteLLM, or supporting other VPN protocols, is not implemented. More VPN
configurations are planned for future releases.

## Limitations

- Only WireGuard client mode is supported. The container is a peer connecting to an existing VPN server, not a server accepting inbound peers. More VPN configurations (server mode, other protocols) are planned for future releases.
- The `wireguard` and `vpn-proxy` services cannot use the gVisor `runsc` runtime because WireGuard requires direct kernel network namespace access.
- A single WireGuard config file (`wg0.conf`) is supported. Multiple tunnels would need a custom setup.
- `vpn-proxy` forwards exactly one Ollama target (`OLLAMA_FORWARD_TARGET`). Routing to multiple Ollama endpoints over the same VPN is not supported without modifying the image.
- Container restart does not renegotiate the WireGuard handshake if the remote peer has rotated keys — manual `make wireguard-config` + restart is needed.
- The config file permissions must be exactly `0600`; LinuxServer WireGuard refuses looser permissions and fails to start.

## Hardware Requirements

| Requirement | Value |
|---|---|
| Kernel | Linux 5.6+ (WireGuard built in) or earlier with `wireguard-dkms` |
| CPU | Any; VPN overhead is <0.2 cores |
| RAM | 64–96 MB |
| `/dev/net/tun` | Must be present on host |
| Docker runtime | Default (runc); gVisor not supported |
