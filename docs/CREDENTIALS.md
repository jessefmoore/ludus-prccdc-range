# CCDC Range — Master Credential Sheet

> ⚠️ Lab/competition credentials. Rotate before any exposure beyond the isolated range.
> All service passwords are overridable via `role_vars` / `global_role_vars` in `ccdc-range.yml`.

## Active Directory (prccdc.local)
| Account | Password | Purpose |
|---------|----------|---------|
| `PRCCDC\Administrator` | `PRccdc-Admin-2026!` | Domain Admin |
| DSRM / safe-mode | `PRccdc-SafeMode-2026!` | Directory restore |
| `prccdcuser` | `PRccdc-User-2026!` | Ludus default low-priv domain user |

### Service accounts (OU=ServiceAccounts,OU=CCDC) — default `PRccdc-Svc-2026!`
`svc_ldap` (Wiki/WordPress/Gitea LDAP bind), `svc_wiki`, `svc_wordpress`, `svc_magento`,
`svc_gitea`, `svc_mysql`, `svc_minio`, `svc_keycloak`, `svc_wazuh` — all in group `CCDC-WebApps`.

### Employee users (OU=Employees) — default `PRccdc-User-2026!`
~10 synthetic staff (e.g. `athompson`, group `CCDC-Employees`). Use these to test AD login to
Wiki.js / WordPress / Gitea. Full list: `Get-ADUser -SearchBase "OU=Employees,OU=CCDC,DC=prccdc,DC=local" -Filter *`.

## Application / service logins
| Service | URL | User | Password |
|---------|-----|------|----------|
| Wiki.js | http://10.50.10.30:8083 | admin@prccdc.local | PRccdc-Wiki-2026! |
| WordPress | http://10.50.20.10/wordpress | local admin `wpadmin` / AD users | PRccdc-WP-Admin-2026! / PRccdc-User-2026! (AD) |
| WordPress DB | 10.50.20.10:3306 | wp_user | PRccdc-WP-2026! |
| Magento | http://10.50.20.20:8085/admin | admin | PRccdc-Magento-2026! |
| Gitea | http://10.50.30.10:3000 | gitadmin | PRccdc-Gitea-2026! |
| Nexus (artifact repo) | http://10.50.30.10:8082 | admin | first-boot: `docker exec ccdc_nexus cat /nexus-data/admin.password` |
| MySQL (data01) | 10.50.30.20:3306 | root / appuser (db `appdb`) | PRccdc-MySQL-Root-2026! / PRccdc-MySQL-2026! |
| MinIO | http://10.50.30.20:9001 | ccdcadmin | PRccdc-Minio-2026! |
| Keycloak | http://10.50.30.30:8080 | admin | PRccdc-Keycloak-2026! |
| Wazuh | https://10.50.40.10 | admin | (installer-generated, see docs/VMS.md) |

## Ludus / Proxmox access
| Who | Login | Password | Scope |
|-----|-------|----------|-------|
| Admin (build) | Ludus user `JM` | (existing) | full |
| Blue Team 1 | Proxmox `prccdc-blue-team-1` (realm pam) | `PRccdc-Blue1-2026!` | CCDC pool console only |

Blue Team API key issued at creation (store securely; reset via `getAPIKey`).
Proxmox GUI: `https://<proxmox-host>:8006`.
