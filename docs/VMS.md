# CCDC Range — VM / Service / Port / Credential Reference

Range **CCDC** (rangeNumber 50) → every IP is `10.50.<vlan>.<octet>`.
AD domain **prccdc.local** (NetBIOS `PRCCDC`). DNS server for all VMs = the DC (`10.50.10.10`).

> All Linux VMs are domain-joined via realmd/SSSD, so you can also log in over SSH with
> `PRCCDC\<aduser>` / `<aduser>@prccdc.local`. Local build creds are listed per VM below.

| VM | OS (template) | IP | Role in range |
|----|---------------|-----|---------------|
| CCDC-dc01   | Win Server 2016 | 10.50.10.10 | AD DC + DNS (forest root) |
| CCDC-desk01 | Win 11 *(⇐Win10)* | 10.50.10.20 | User desktop, RDP/SSH, PII target files, Squid client |
| CCDC-wiki01 | Ubuntu 22.04 | 10.50.10.30 | Wiki.js (AD login) |
| CCDC-proxy01| Debian 12 | 10.50.10.40 | Squid forward proxy |
| CCDC-web01  | Win Server 2022 | 10.50.20.10 | WordPress / media web (AD login) |
| CCDC-shop01 | Ubuntu 22.04 *(⇐Rocky)* | 10.50.20.20 | Magento e-commerce |
| CCDC-dev01  | Debian 12 *(⇐Deb13)* | 10.50.30.10 | Gitea + JFrog Artifactory (Gitea AD login) |
| CCDC-data01 | Ubuntu 22.04 | 10.50.30.20 | MinIO + MySQL |
| CCDC-sso01  | Ubuntu 22.04 | 10.50.30.30 | Keycloak + waitAPI + RideAPI |
| CCDC-wazuh01| Ubuntu 22.04 | 10.50.40.10 | Wazuh SIEM manager |
| (router)    | Debian *(⇐Alpine)* | 10.50.x.254 / WAN | Range firewall / gateway |

---

## VLAN 10 — Corporate LAN

### CCDC-dc01 — Active Directory DC + DNS  (10.50.10.10)
| Item | Value |
|------|-------|
| Services | AD DS, DNS, Kerberos, LDAP |
| Ports | 53, 88, 135, 389, 445, 464, 636, 3268/3269, 3389 (RDP) |
| Domain Admin | `PRCCDC\Administrator` / `PRccdc-Admin-2026!` |
| DSRM / safe mode | `PRccdc-SafeMode-2026!` |
| Created by role | `ccdc_ad_accounts` (OUs, service + employee accounts) |
| Verify | `Get-ADUser -Filter *` ; `nslookup dc01.prccdc.local` |

### CCDC-desk01 — Windows Desktop  (10.50.10.20)
| Item | Value |
|------|-------|
| Services | RDP (3389), OpenSSH server (22) |
| Login | `PRCCDC\<employee>` (e.g. `athompson`) / `PRccdc-User-2026!`, or local admin from Ludus |
| Planted data | `C:\CCDC-Data\`, `C:\Users\Public\Desktop\Sensitive\`, `...\Documents\HR\` — synthetic PII, fake credit cards, SSNs, password vault (role `ccdc_pii`) |
| Proxy | Auto-configured via **GPO** ("CCDC Squid Proxy", role `ccdc_proxy_gpo` on the DC) → domain users get `10.50.10.40:3128` at logon. Verified: `prccdcuser` HKCU ProxyServer set + desk01 traffic seen in Squid log. (`scripts/set-desktop-proxy.ps1` is the manual per-user fallback.) |
| Verify | RDP in; confirm PII files exist; `netsh winhttp show proxy` |

### CCDC-wiki01 — Wiki.js  (10.50.10.30)
| Item | Value |
|------|-------|
| URL | http://10.50.10.30:8083/ |
| Local admin (first-run) | `admin@prccdc.local` / `PRccdc-Wiki-2026!` |
| AD login | via LDAP to DC; bind `svc_ldap` — enable in Admin → Auth (see `roles/ccdc_wikijs/files/ldap-config.md`) |
| Containers | `wiki` (requarks/wiki:2) + `db` (postgres:16), dir `/opt/ccdc/wikijs` |
| Verify | `curl -I http://10.50.10.30:8083/` ; `docker compose ps` |

### CCDC-proxy01 — Squid  (10.50.10.40)
| Item | Value |
|------|-------|
| Service / port | Squid forward proxy, TCP **3128** |
| Allowed clients | `10.50.0.0/16` |
| Blocklist var | `ludus_squid_blocked_domains` (empty by default) |
| Verify | `curl -x http://10.50.10.40:3128 http://example.com -I` ; log `/var/log/squid/access.log` |

---

## VLAN 20 — DMZ

### CCDC-web01 — WordPress / media  (10.50.20.10)
| Item | Value |
|------|-------|
| URL | http://10.50.20.10/wordpress |
| Club site | **http://10.50.20.10/club/** — static GrayHats-club landing page (grayhats.club style) |
| Stack | XAMPP (Apache+PHP+MariaDB) via Chocolatey |
| DB | db `wordpress`, user `wp_user` / `PRccdc-WP-2026!` (local MariaDB root: blank/XAMPP default) |
| AD login | authLdap plugin, bind `svc_ldap` → AD users (e.g. `athompson`) log in at `/wordpress/wp-login.php` |
| Note | First-run WordPress wizard (site title / WP admin) is one manual browser step |
| Verify | Apache + MariaDB running; club page + `/wordpress/` return HTTP 200 (validated) |

### CCDC-shop01 — Magento  (10.50.20.20)
| Item | Value |
|------|-------|
| URL | http://10.50.20.20:8085/  (admin at `/admin`) |
| Admin | `admin` / `PRccdc-Magento-2026!` |
| Stack | bitnami/magento + bitnami/mariadb + bitnami/opensearch, dir `/opt/ccdc/magento` |
| AD login | best-effort (see role README: Magento LDAP module or Keycloak SSO front) |
| Note | First provisioning is slow (10–20+ min) and RAM-hungry |
| Verify | `docker compose ps` ; `docker compose logs -f magento` |

---

## VLAN 30 — Internal Services

### CCDC-dev01 — Gitea + Nexus artifact repo  (10.50.30.10)
| Item | Value |
|------|-------|
| Gitea | http://10.50.30.10:3000/  · SSH 2222 · admin `gitadmin` / `PRccdc-Gitea-2026!` |
| Gitea AD login | LDAP source `PRCCDC-AD` (bind `svc_ldap`) — AD users log in with sAMAccountName |
| Nexus (artifact repo) | http://10.50.30.10:8082/  · `admin` / `docker exec ccdc_nexus cat /nexus-data/admin.password` |
| JFrog option | set `ccdc_devtools_artifact_backend: artifactory` + dev01 to 12 GB, redeploy (see VALIDATION.md) |
| Stack dir | `/opt/ccdc/devtools` |
| Verify | `docker compose ps` ; `docker exec -u git ccdc_gitea gitea admin auth list` |

### CCDC-data01 — MinIO + MySQL  (10.50.30.20)
| Item | Value |
|------|-------|
| MySQL | `10.50.30.20:3306` · root `PRccdc-MySQL-Root-2026!` · db `appdb` (tables: customers, orders), user `appuser` / `PRccdc-MySQL-2026!` |
| MinIO API | http://10.50.30.20:9000 |
| MinIO Console | http://10.50.30.20:9001 · `ccdcadmin` / `PRccdc-Minio-2026!` · bucket `company-data` |
| Stack dir | `/opt/ccdc/data` |
| Verify | `mysql -h10.50.30.20 -uappuser -p` ; MinIO console login |

### CCDC-sso01 — Keycloak + waitAPI + RideAPI  (10.50.30.30)
| Item | Value |
|------|-------|
| Keycloak | http://10.50.30.30:8080/ · admin `admin` / `PRccdc-Keycloak-2026!` |
| waitAPI | http://10.50.30.30:8081/ (JSON ride wait-times) |
| RideAPI | http://10.50.30.30:8082/ (JSON ride catalog) |
| AD federation | optional LDAP user federation → AD (`files/keycloak-realm-import.json`, bind `svc_ldap`) |
| Stack dir | `/opt/ccdc/sso` |
| Verify | `curl http://10.50.30.30:8081/` ; Keycloak admin console |

---

## VLAN 40 — Security

### CCDC-wazuh01 — Wazuh SIEM  (10.50.40.10)
| Item | Value |
|------|-------|
| Dashboard | https://10.50.40.10/ (default `admin` / password printed by installer — see `wazuh-passwords.txt` on the host) |
| Ports | 443 (dashboard), 1514/1515 (agent), 55000 (API) |
| Agents | every other VM runs `aleemladha.ludus_wazuh_agent` pointed at `10.50.40.10` |
| Verify | Dashboard → Agents shows the range VMs enrolled |

> Wazuh sets a randomized admin password at install; retrieve it on the manager
> (`sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt`).
