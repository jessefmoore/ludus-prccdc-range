# Reusable Prompt — Build a CCDC Range in Ludus

A fill-in-the-blanks prompt for spinning up a new Collegiate Cyber Defense
Competition (CCDC) range in Ludus. Distilled from the `ludus-prccdc-range` build.
Replace every `<...>` placeholder with your specifics (OS, web apps, topology),
then paste it as your opening prompt.

---

## The Prompt

> Build a CCDC competition range in Ludus. I'm Ludus user `<USERID>` (admin);
> project dir `<PATH>`. Use the Ludus MCP server as the interface (no local
> `ludus` CLI).
>
> **Domain & topology:** AD domain `<DOMAIN>`, range ID `<RANGE_ID>`, IP scheme
> `10.<2nd-octet>.<VLAN>.<host>`. Segment into VLANs behind a router/firewall:
> - VLAN 10 Corporate: DC (AD+DNS), a desktop, `<...>`
> - VLAN 20 DMZ: `<web apps>`
> - VLAN 30 Internal: `<dev/data/SSO services>`
> - VLAN 40 Security: SIEM
>
> **VMs / OS:** `<list each VM: hostname, OS, VLAN.octet, purpose>`.
>
> **Services / web apps:** `<list apps>`. Deliver each as a custom Docker-based
> Ansible role under `roles/` (most have no ready Ludus role). Integrate web apps
> with AD via LDAP (bind + per-app service accounts). Domain-join all Linux hosts
> (realmd/sssd role). Seed synthetic PII/business data where relevant. Stand up
> `<SIEM>` as the security monitor.
>
> **Template strategy:** only use templates already built on my Ludus server. For
> any OS not built (building from ISO is slow/risky), **substitute** the closest
> built template, clearly document the substitution, and generate
> `scripts/build-templates.sh` to build the real ones later.
>
> **Access:** create a non-admin team user with Proxmox **console-only** scoped
> access to the range.
>
> **Deliverables:** custom roles under `roles/`, a master credential sheet +
> `docs/` (network, VMs, access, validation, AD integration), all as a git repo.
> Every service password overridable via `role_vars`/`global_role_vars` in the
> range config.
>
> Before deploying, show me the VM/service plan and the template substitutions
> for approval.

---

## Notes for next time

- **Fill in the OS/app lists concretely** — that's what drives the whole build.
  Everything else (LDAP wiring, Docker roles, docs, template substitution) is
  repeatable scaffolding.
- **Keep the "show me the plan before deploying" line** — it catches template
  mismatches before a deploy is wasted.
- **Credentials are committed by design** in these builds (defaults in each
  role's `defaults/main.yml`, overridable via `role_vars`). Keep the repo
  **private**, or rotate/vault before any public exposure.

## Reference: what the prccdc build produced (a concrete example)

- **Topology:** 4 VLANs (Corporate / DMZ / Internal / Security) behind a Ludus
  native Debian router used as the firewall.
- **Custom roles:** `ccdc_ad_accounts`, `ccdc_pii`, `ccdc_linux_domain_join`,
  `ccdc_wordpress`, `ccdc_magento`, `ccdc_devtools` (Gitea+Nexus), `ccdc_data`
  (MinIO+MySQL), `ccdc_sso` (Keycloak), `ccdc_wikijs`, `ccdc_proxy_gpo`,
  `ludus_squid`.
- **Template substitutions used:** Alpine router → Debian router + iptables;
  Win10 → win11-22h2; Debian13 → debian-12; Rocky → ubuntu-22.04. Win2016 DC,
  Win2022 web, Ubuntu 22 servers used as-is.
- **SIEM:** Wazuh via `aleemladha.wazuh_server_install` +
  `aleemladha.ludus_wazuh_agent`. Docker via `geerlingguy.docker`.
