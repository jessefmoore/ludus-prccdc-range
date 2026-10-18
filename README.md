# PRCCDC — Collegiate Cyber Defense Competition Range (Ludus)

A full CCDC-style enterprise environment built in [Ludus](https://ludus.cloud): an Active Directory
domain, public web (WordPress + Magento), internal dev/data/SSO services, a wiki with AD login, a
Squid proxy, and a Wazuh SIEM — all domain-joined, documented, and reproducible.

- **Range ID:** `CCDC` (rangeNumber **50** → all IPs `10.50.<vlan>.<octet>`)
- **AD domain:** `prccdc.local` (DC + DNS @ `10.50.10.10`)
- **11 VMs across 5 VLANs** behind a Ludus router/firewall

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
| CCDC-score01 | Ubuntu24 | 10.50.50.10 | Quotient scoring engine (scorebot, not domain-joined) |

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
  VALIDATION.md           # service validation status + known deploy gotchas
scripts/
  install-roles.sh        # install all roles into Ludus
  deploy.sh               # push config + deploy
  build-templates.sh      # build the real Win10 / Debian13 / Rocky templates
  create-team-user.sh     # add a team + scoped Proxmox access
  set-desktop-proxy.ps1   # point the desktop at Squid
  snapshot.sh             # snapshot / rollback for competition resets
roles/                    # 13 custom Ansible roles (see ROLE_CONVENTIONS.md)
  ludus_squid, ccdc_ad_accounts, ccdc_pii, ccdc_linux_domain_join,
  ccdc_wordpress, ccdc_magento, ccdc_devtools, ccdc_data, ccdc_sso, ccdc_wikijs,
  ccdc_proxy_gpo, ccdc_win_openssh, ccdc_scoring
```

## Quick start (Ludus CLI v2)

This repo targets the [Ludus v2 CLI](https://docs.ludus.cloud/docs/using-ludus/cli). Range-scoped
commands now take a global `-r/--range` flag (a user can own several ranges), and admins act on
another user's behalf with `-u/--user` instead of the old `--user` long flag.

```bash
# 0. Point the CLI at your Ludus server and provide your API key (once)
export LUDUS_URL=https://<LUDUS_HOST>:8080      # or set `url:` in ~/.config/ludus/config.yml
# You don't need a brand-new user for this — reuse your existing admin
# account's key (e.g. JM's) rather than creating one:
export LUDUS_API_KEY=<YOUR_ADMIN_API_KEY>
# (or skip the env var and run `ludus apikey` to store it in your system keyring instead)

# 1. Create the range (pins the IP scheme: rangeNumber 50 -> 10.50.<vlan>.<octet>)
ludus range create -n CCDC -r CCDC --range-number 50

# 2. Install every custom/community role this range needs
scripts/install-roles.sh

# 3. Push the config and deploy (equivalent to, and wrapped by, scripts/deploy.sh):
ludus range config set -f ccdc-range.yml -r CCDC
ludus range deploy -r CCDC                      # 1-3 h for all VMs + AD
#   or just:
scripts/deploy.sh CCDC

# 4. Watch progress / check status
ludus range logs -f -r CCDC
ludus range list -r CCDC

# 5. Add a competition team with console-only Proxmox access
scripts/create-team-user.sh BLUE1 "PRCCDC Blue Team 1" CCDC
```

> Deploying on behalf of another Ludus user (admin only)? Add `-u <userid>` to `range config set`,
> `range deploy`, `range logs`, and `range list` — see `scripts/deploy.sh CCDC <teamid>`.

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

## Using the Ludus MCP server with Claude Code

Ludus ships an official MCP server so Claude Code can drive range/template/snapshot operations
directly instead of shelling out to the `ludus` CLI. Full docs:
https://docs.ludus.cloud/docs/using-ludus/mcp/#claude-code

**Prerequisites:** Node.js 20+, a Ludus server URL, and an API key — reuse an existing admin
account's key (e.g. JM's, same as the quick start above), or mint a dedicated one if you'd rather
scope this integration's blast radius separately.

```bash
claude mcp add ludus -- npx -y @badsectorlabs/ludus-mcp \
  --url https://<LUDUS_HOST>:8080 --api-key <YOUR_API_KEY>
```

Or configure it via environment variables instead of flags:

```bash
export LUDUS_URL=https://<LUDUS_HOST>:8080
export LUDUS_API_KEY=<YOUR_API_KEY>
claude mcp add ludus -- npx -y @badsectorlabs/ludus-mcp
```

Once added, `claude mcp list` should show `ludus` as connected, and Claude Code can call Ludus
operations (range create/deploy/status, templates, snapshots, blueprints) for this repo without
you running the `ludus` CLI by hand. Scope the server to this project (`claude mcp add --scope
project ...`) if you want it checked into `.mcp.json` for teammates, or keep it user-scoped if the
API key is personal.

## Ludus skills (optional per Ludus, treat as mandatory for this repo)

Ludus itself documents this package as optional — the MCP server works without it. For this repo,
install it anyway and treat it as mandatory: the MCP server above gives Claude *execution* (it can
call the Ludus API), but not Ludus-specific *knowledge* — how this range's CLI flags work, how to
read `ccdc-range.yml`, or how to recognize a known failure like the ADWS timing issue in
`docs/VALIDATION.md`. Skipping it means Claude is calling the Ludus API blind. Per the Ludus docs
(https://docs.ludus.cloud/docs/using-ludus/mcp/):

> The MCP server handles execution; skills provide context. They work independently or together.

Install it **project-scoped**, from the repo root, so it's committed and every future contributor
who clones this repo gets Ludus-aware Claude Code help automatically:

```bash
npx skills add https://gitlab.com/badsectorlabs/ludus-skills
```

Confirm it landed under this repo's `.claude/skills/` (check with `git status`), then commit it
like any other repo file:

```bash
git add .claude/skills
git commit -m "Add ludus-skills package for Claude Code"
```

Do this before relying on Claude Code to deploy or troubleshoot this range through the MCP
server — without it, Claude has a way to run range operations but no grounding in Ludus's CLI,
range-config format, or this repo's known gotchas.

## Example prompt — deploy this range

With both the MCP server and `ludus-skills` in place, paste this into Claude Code from the repo
root to run the same steps as the quick start above, but through the MCP server instead of the
`ludus` CLI directly:

> Using the Ludus MCP server, deploy the `CCDC` range for this repo. Create range `CCDC` with
> range-number `50` if it doesn't already exist, install the custom/community roles under
> `roles/` (see `scripts/install-roles.sh` for the exact list), push `ccdc-range.yml` as the
> range config, then deploy it. If the first deploy pass errors on the DC with an Active
> Directory Web Services timing issue, that's a known transient (see `docs/VALIDATION.md`) —
> redeploy once more. Report range status and any failed roles when done.
