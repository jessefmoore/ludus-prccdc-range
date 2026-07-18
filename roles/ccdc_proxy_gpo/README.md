# ccdc_proxy_gpo

Creates and links a Group Policy Object on the PRCCDC domain controller that points domain users at
the CCDC **Squid proxy** (`CCDC-proxy01`, `10.50.10.40:3128`). Because it's created declaratively on
every deploy, the proxy setting **survives range rebuilds** (unlike a one-off registry script).

## What it does (runs on the primary DC)
- Ensures a GPO named `CCDC Squid Proxy` exists.
- Sets the per-user WinINET proxy under **User Configuration** → `HKCU\...\Internet Settings`:
  - `ProxyEnable = 1`, `ProxyServer = 10.50.10.40:3128`, `ProxyOverride = <bypass list>`, `AutoDetect = 0`
- Links the GPO to the domain root (or an OU via `ccdc_proxy_gpo_link_dn`).

Because the proxy is per-user, it applies to any AD user at logon on any domain machine — including
`CCDC-desk01`, the intended client.

## Key vars (`defaults/main.yml`)
| var | default |
|-----|---------|
| `ccdc_proxy_gpo_server` | `10.50.10.40:3128` |
| `ccdc_proxy_gpo_bypass` | `<local>;10.50.*.*;*.prccdc.local;localhost` |
| `ccdc_proxy_gpo_link_dn` | `""` (empty = domain root) |

## Verify
On a domain client, logged in as an AD user:
```
gpupdate /force        # then log off/on
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer
# -> ProxyServer  REG_SZ  10.50.10.40:3128
```
Then browse the web and watch it on the proxy: `tail -f /var/log/squid/access.log` on CCDC-proxy01.

On the DC: `Get-GPO -Name "CCDC Squid Proxy"` and `Get-GPInheritance -Target (Get-ADDomain).DistinguishedName`.
