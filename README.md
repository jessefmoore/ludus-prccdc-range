# PRCCDC — Collegiate Cyber Defense Competition Range (Ludus)

A full CCDC-style enterprise environment built in [Ludus](https://ludus.cloud): an Active Directory
domain, public web (WordPress + Magento), internal dev/data/SSO services, a wiki with AD login, a
Squid proxy, and a Wazuh SIEM — all domain-joined, documented, and reproducible.

- **Range ID:** `CCDC` (rangeNumber **50** → all IPs `10.50.<vlan>.<octet>`)
- **AD domain:** `prccdc.local` (DC + DNS @ `10.50.10.10`)
- **10 VMs across 4 VLANs** behind a Ludus router/firewall

## Topology
| VM | OS | IP | Services |
|----|----|----|----------|
| CCDC-dc01 | Win2016 | 10.50.10.10 | AD DC + DNS |
| CCDC-desk01 | Win11 *(⇐Win10)* | 10.50.10.20 | Desktop RDP/SSH, PII/fake-card files, Squid client |
| CCDC-wiki01 | Ubuntu22 | 10.50.10.30 | Wiki.js (AD login) |
| CCDC-proxy01 | Debian12 | 10.50.10.40 | Squid proxy |
| CCDC-web01 | Win2022 | 10.50.20.10 | WordPress / media (AD login) |
| CCDC-shop01 | Ubuntu22 *(⇐Rocky)* | 10.50.20.20 | Magento |
| CCDC-dev01 | Debian12 *(⇐Deb13)* | 10.50.30.10 | Gitea + JFrog (Gitea AD login) |
| CCDC-data01 | Ubuntu22 | 10.50.30.20 | MinIO + MySQL |
| CCDC-sso01 | Ubuntu22 | 10.50.30.30 | Keycloak + waitAPI + RideAPI |
| CCDC-wazuh01 | Ubuntu22 | 10.50.40.10 | Wazuh SIEM |

## Repo layout
```
ccdc-range.yml            # the Ludus range config (source of truth)
docs/
  ACCESS-URLS.md          # quick reference: all web URLs + how to get on-network
  VMS.md                  # per-VM services, ports, credentials
  CREDENTIALS.md          # master credential sheet
  NETWORK.md              # VLANs + firewall + hardening ruleset
  ACCESS-CONTROL.md       # team Proxmox console-only access
  AD-INTEGRATION.md       # domain join + service accounts + LDAP wiring
scripts/
  install-roles.sh        # install all roles into Ludus
  deploy.sh               # push config + deploy
  build-templates.sh      # build the real Win10 / Debian13 / Rocky templates
  create-team-user.sh     # add a team + scoped Proxmox access
  set-desktop-proxy.ps1   # point the desktop at Squid
  snapshot.sh             # snapshot / rollback for competition resets
roles/                    # 10 custom Ansible roles (see ROLE_CONVENTIONS.md)
  ludus_squid, ccdc_ad_accounts, ccdc_pii, ccdc_linux_domain_join,
  ccdc_wordpress, ccdc_magento, ccdc_devtools, ccdc_data, ccdc_sso, ccdc_wikijs
```

## Rebuild from scratch
```bash
scripts/install-roles.sh                 # roles into Ludus
# create range CCDC (rangeNumber 50) if it doesn't exist, then:
scripts/deploy.sh CCDC                    # push config + deploy (1-3 h)
scripts/create-team-user.sh BLUE1 "PRCCDC Blue Team 1" CCDC
```

## Template substitutions (and how to get the real OSes)
The requested Alpine / Windows 10 / Debian 13 / Rocky templates were **not pre-built** on this
Ludus host, so the range uses built substitutes (documented inline in `ccdc-range.yml`). The Ludus
Debian **router is the firewall** (Alpine's role). Build the exact OSes with
`scripts/build-templates.sh`, then swap the template names in `ccdc-range.yml` and redeploy.

## Notes on service delivery
Linux app services run as Docker Compose stacks (via `geerlingguy.docker`) authored as custom Ludus
roles — the most reliable way to stand up WordPress-adjacent, Magento, Gitea/JFrog, MinIO/MySQL,
Keycloak, and Wiki.js. Wazuh uses the community `aleemladha` roles. See `docs/` for everything.

Some apps have a documented **one-time manual finalize** (WordPress install wizard, Wiki.js admin
first-run + LDAP enable, Artifactory first login) — called out in each role's `README.md`.
