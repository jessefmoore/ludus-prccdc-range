# ccdc.ludus_squid

A [Squid](http://www.squid-cache.org/) forward proxy for CCDC range machines
(especially the Windows desktop) to route outbound web traffic through. Runs on
a Debian/Ubuntu Linux VM and gives instructors a single choke point for
allow-listing client subnets and blocklisting sites.

## What it does

- Installs `squid` via apt.
- Templates `/etc/squid/squid.conf` with:
  - `http_port` set from `ludus_squid_port`.
  - `acl` + `http_access allow` for the configured client subnets.
  - Standard safe-port rules and a `deny CONNECT` to non-SSL ports.
  - `visible_hostname` and a `cache_dir`, with access logging to
    `/var/log/squid/access.log`.
  - An optional `dstdomain` blocklist so instructors can deny specific sites.
- Ensures the log and cache directories exist, validates the config with
  `squid -k parse`, and enables + (re)starts the service on config change.

## Ports

| Port | Protocol | Purpose                       |
|------|----------|-------------------------------|
| 3128 | TCP      | HTTP forward proxy (default)  |

## Variables (`defaults/main.yml`)

| Variable                        | Default                                                  | Description                                              |
|---------------------------------|----------------------------------------------------------|----------------------------------------------------------|
| `ludus_squid_port`              | `3128`                                                   | Port Squid listens on.                                   |
| `ludus_squid_allowed_cidrs`     | `['10.0.0.0/8','192.168.0.0/16','172.16.0.0/12']`        | Client subnets permitted to use the proxy.               |
| `ludus_squid_blocked_domains`   | `[]`                                                     | `dstdomain` entries to deny (e.g. `['.example.com']`).   |
| `ludus_squid_visible_hostname`  | `ccdc-proxy`                                             | `visible_hostname` reported by Squid.                    |

## Pointing the Windows desktop at the proxy

Set the system proxy to the Squid VM's IP and port `3128`. Either:

- **GUI:** Settings → Network & Internet → Proxy → Manual proxy setup →
  Address `<proxy-ip>`, Port `3128`.
- **PowerShell (per-user WinINET):**

  ```powershell
  $reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
  Set-ItemProperty -Path $reg -Name ProxyEnable -Value 1
  Set-ItemProperty -Path $reg -Name ProxyServer -Value '<proxy-ip>:3128'
  ```

- **System-wide (WinHTTP), e.g. for services:**

  ```cmd
  netsh winhttp set proxy <proxy-ip>:3128
  ```

## Verify

From a client on an allowed subnet:

```bash
curl -x http://<proxy-ip>:3128 http://example.com -I
```

A `200 OK` (with a `Via:`/`X-Cache` header from `ccdc-proxy`) confirms traffic
is flowing through Squid. On the proxy VM, watch requests live with:

```bash
tail -f /var/log/squid/access.log
```
