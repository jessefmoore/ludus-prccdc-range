# ccdc_scoring

Deploys the **Quotient** scoring engine ([dbaseqp/Quotient](https://github.com/dbaseqp/Quotient))
via docker compose on `CCDC-score01` and configures it to score the PRCCDC **CCDC**
range (`prccdc.local`, `10.50.<vlan>.<octet>`).

## Scoreboard
- Web UI: **http://10.50.50.10/** (server on port 80)
- Admin: `admin` / `PRccdc-Score-Admin-2026!` · Team: `blue1` / `PRccdc-Score-Blue1-2026!`
- Starts **running** (`ccdc_scoring_start_paused: false`, `ccdc_scoring_autostart: true`) —
  the role logs in over the API, activates `blue1`, and starts the competition so a
  fresh rebuild is scoring immediately. Set both to the paused/false values for a real
  competition where an admin starts scoring by hand.
- Stack: `server` + `runner` ×5 + PostgreSQL + Redis (the optional `divisor`
  IP-rotator is skipped). Config at `/opt/ccdc/quotient/config/event.conf`.

## Scored services (30 checks across 10 boxes — well over the required 10)
| Box | IP | Checks |
|-----|-----|--------|
| dc01 (Win2016) | 10.50.10.10 | **ping**, **DNS** (A `prccdc.local`), **LDAP** (bind Administrator), **RDP** |
| desk01 (Win11) | 10.50.10.20 | **RDP**, **SSH** (AD `athompson`, hostname ∋ `desk01`) |
| wiki01 (Ubuntu) | 10.50.10.30 | **Web** Wiki.js :8083 (text `wiki`), **SSH** |
| proxy01 (Debian) | 10.50.10.40 | **Custom** functional proxy (fetches a URL *through* Squid → 200), **SSH** |
| web01 (Win2022) | 10.50.20.10 | **Web** WordPress `/wordpress/` (asserts site title `PRCCDC GrayHats Club` + `wp-login.php` renders), **Web** club page `/club/` (text `grayhats`), **RDP** |
| shop01 (Ubuntu) | 10.50.20.20 | **Web** Magento :8085 (text `magento`), **SSH** |
| dev01 (Debian) | 10.50.30.10 | **Web** Gitea :3000 (text `gitea`), **Web** Nexus :8082, **TCP** gitea-ssh 2222, **SSH** |
| data01 (Ubuntu) | 10.50.30.20 | **SQL** MySQL 3306 (queries seeded `customers`/`orders` rows on `appdb`), **Custom** MinIO authenticated S3 (bucket exists + read seeded object), **Web** MinIO console :9001, **SSH** |
| sso01 (Ubuntu) | 10.50.30.30 | **Web** Keycloak `/realms/master`, **Custom** Keycloak OIDC token (password grant → access_token), **Web** waitAPI :8081, **Web** RideAPI :8082, **SSH** |
| wazuh01 (Ubuntu) | 10.50.40.10 | **TCP** dashboard 443, **TCP** Wazuh API 55000, **SSH** |

Covers the requested **http, ssh, rdp, website-text** plus DNS, LDAP, SQL and raw
TCP. Checks are editable live in the admin UI, or via `event.conf` + redeploy.

### Deep checks assert role-seeded data (never hand-injected)
The "deep" content checks match data that is **produced by other roles at deploy
time**, so scoring is fully automated and reproducible on every rebuild — nothing
is entered by hand in the Quotient UI. The asserted values live in
`defaults/main.yml` and must stay in sync with their source role:

| Scored value (var) | Produced by |
|--------------------|-------------|
| `ccdc_scoring_wp_site_title` (WordPress `<title>`) | `ccdc_wordpress` → `ccdc_wordpress_site_title` |
| `ccdc_scoring_sql_customer_name` (`customers` id=1) | `ccdc_data` → `templates/seed.sql.j2` |
| `ccdc_scoring_sql_order_product` (`orders` id=1) | `ccdc_data` → `templates/seed.sql.j2` |

To score against **new** data, add it to the seeding role (e.g. more `INSERT`s in
`ccdc_data/templates/seed.sql.j2`) and reference it here — do not add it only in
the scoreboard.

### Custom checks (where native checks can't validate the real function)
Three checks are Quotient `[[Box.Custom]]` scripts (in `files/custom-checks/`,
copied to `/opt/ccdc/quotient/custom-checks/` → mounted into the runner at
`/app/checks/`). Each exits 0 + prints `SUCCESS` (matched by `Regex="SUCCESS"`):

| Check | Script | Why custom |
|-------|--------|-----------|
| `proxy01-proxy` | `squid_proxy.sh` | actually **forwards a request through Squid** (curl `-x`) and requires 200 — a TCP probe only proves the port is open |
| `data01-minio-s3` | `minio_s3.py` | **authenticated S3**: bucket-exists + read the seeded object (needs the `minio` py SDK, auto-added to the runner via `requirements.txt`) |
| `sso01-keycloak-token` | `keycloak_token.sh` | real **OIDC password grant** that must return an `access_token` |

Runner tooling available to custom checks (from `Dockerfile.runner`): `curl`,
`jq`, `python3`, `bind-tools`, `openssh`, `sshpass`, plus any package listed in
`custom-checks/requirements.txt`. Scripts are mounted (no rebuild to change
logic); adding a python dependency rebuilds the runner on the next deploy.

## Credlists (`config/credlists/`)
- `linux` — AD employee `athompson` (SSH to every domain-joined Linux host + desk01 OpenSSH; SSSD short names)
- `windows` — `Administrator` (LDAP bind to the DC)
- `db` — `appuser` (MySQL `appdb` on data01)

All overridable via `role_vars` / `global_role_vars`.

## Verify
```
curl -I http://10.50.50.10/
docker compose -f /opt/ccdc/quotient/docker-compose.yml ps
```
Then open the UI, log in as admin, and watch the checks turn green (or use the
paused settings and press start manually for a competition).
