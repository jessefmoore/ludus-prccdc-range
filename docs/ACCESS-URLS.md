# CCDC Range — Access URLs (Quick Reference)

Range **CCDC** · domain **prccdc.local** · all IPs are internal (`10.50.<vlan>.<octet>`).
Full per-VM detail is in [VMS.md](VMS.md); all passwords are in [CREDENTIALS.md](CREDENTIALS.md).

> **These URLs are only reachable from *inside* the range** (a range VM like `desk01`) or over the
> range **WireGuard VPN** — see "Getting on-network" at the bottom.

## Web apps
| Service | URL | Login |
|---------|-----|-------|
| GrayHats club site (static) | http://10.50.20.10/club/ | none (public landing page) |
| WordPress / media | http://10.50.20.10/wordpress | AD user (e.g. `athompson` / `PRccdc-User-2026!`) or the wizard-created WP admin |
| Wiki.js | http://10.50.10.30:8083 | `admin@prccdc.local` / `PRccdc-Wiki-2026!` — then AD login once LDAP is enabled |
| Gitea | http://10.50.30.10:3000 | `gitadmin` / `PRccdc-Gitea-2026!` — or any AD user (LDAP) |
| Nexus (artifact repo) | http://10.50.30.10:8082/ | `admin` / first-boot pw: `docker exec ccdc_nexus cat /nexus-data/admin.password` |
| Magento (store) | http://10.50.20.20:8085 | storefront (no login) |
| Magento (admin) | http://10.50.20.20:8085/admin | `admin` / `PRccdc-Magento-2026!` |
| Keycloak (SSO) | http://10.50.30.30:8080 | `admin` / `PRccdc-Keycloak-2026!` |
| MinIO console | http://10.50.30.20:9001 | `ccdcadmin` / `PRccdc-Minio-2026!` |
| Wazuh (SIEM) | https://10.50.40.10 | `admin` / installer-generated (see [VMS.md](VMS.md)) |
| Quotient scoreboard | http://10.50.50.10/ | admin `admin` / `PRccdc-Score-Admin-2026!` · team `blue1` / `PRccdc-Score-Blue1-2026!` |

## APIs (JSON)
| Service | URL |
|---------|-----|
| waitAPI (ride wait times) | http://10.50.30.30:8081/ |
| RideAPI (ride catalog) | http://10.50.30.30:8082/ |
| MinIO S3 API | http://10.50.30.20:9000 |

## Data services (not web)
| Service | Endpoint | Login |
|---------|----------|-------|
| MySQL (data01) | `10.50.30.20:3306` | `appuser` / `PRccdc-App-2026!` (root `PRccdc-Mysql-2026!`) |
| WordPress DB | `10.50.20.10:3306` | `wp_user` / `PRccdc-WP-2026!` |
| Gitea SSH | `10.50.30.10:2222` | git over SSH |
| Squid proxy | `10.50.10.40:3128` | forward proxy for the desktop |

## Remote-desktop / shell access
| Target | How |
|--------|-----|
| Windows desktop `desk01` | RDP `10.50.10.20:3389` or SSH `10.50.10.20:22` — `PRCCDC\<aduser>` |
| Windows `dc01` / `web01` | RDP `10.50.10.10` / `10.50.20.10` — `PRCCDC\Administrator` / `PRccdc-Admin-2026!` |
| Any Linux VM | SSH as `PRCCDC\<aduser>` (domain-joined) or the Ludus local user |
| Proxmox console (teams) | https://\<proxmox-host\>:8006 → `prccdc-blue-team-1` / `PRccdc-Blue1-2026!` (console-only) |

---

## Getting on-network (so these URLs resolve from your workstation)

**Option A — WireGuard VPN into the range (recommended):**
```bash
# generate your VPN profile, then import it into WireGuard
ludus user wireguard --user JM > ccdc-wg.conf      # admin: whole-range access
wg-quick up ./ccdc-wg.conf
# now browse to any 10.50.x.x URL above
```
(API equivalent: `getWireguardConfig`.)

**Option B — from inside the range:** open the `desk01` console/RDP in Proxmox and browse from there.

**Option C — RDP bundle:** `ludus range rdp` downloads ready-made `.rdp` files for the Windows VMs.

> Tip: add these to the range DNS or your hosts file for friendlier names, e.g.
> `10.50.10.30 wiki.prccdc.local`, `10.50.30.10 gitea.prccdc.local`, `10.50.20.10 www.prccdc.local`.
