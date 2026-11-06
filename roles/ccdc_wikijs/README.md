# ccdc_wikijs

Deploys [Wiki.js](https://js.wiki/) (a documentation wiki) on a Linux VM
(Ubuntu 22.04) via **Docker Compose**, backed by PostgreSQL 16, and wires it so
**Active Directory** users in domain `prccdc.local` can log in with their AD
accounts over LDAP. Intended as a CCDC range target service.

Docker and the `docker compose` plugin are assumed already installed (the VM
lists `geerlingguy.docker` before this role). This role does **not** install
Docker and does **not** use the `community.docker` collection.

## What it does

- Creates the stack directory `/opt/ccdc/wikijs` (`0755`).
- Templates `docker-compose.yml` with two services:
  - **db** — `postgres:16`, database/user/password from vars, persistent
    named volume `wikijs_db`, with a `pg_isready` healthcheck.
  - **wiki** — `ghcr.io/requarks/wiki:2`, `DB_TYPE=postgres`, `DB_HOST=db`,
    `DB_PORT=5432`, `DB_USER/PASS/NAME` from vars, `depends_on: db (healthy)`,
    `restart: unless-stopped`. Wiki.js serves HTTP on container port **3000**,
    published to host **`ccdc_wikijs_port`** (default **8083**) and also to host
    **3000**.
- Drops two reference/support files into the stack dir:
  - `ldap-config.md` — the exact, ready-to-paste AD/LDAP strategy settings.
  - `ldap-strategy.sql` — the rendered best-effort DB seed (see below).
- Brings the stack up with `docker compose up -d` (idempotent: guarded by a
  compose-changed / not-running check).
- **Automatically provisions the local admin account** by calling Wiki.js's
  first-run `POST /finalize` setup endpoint once the stack is up (idempotent —
  detected by admin row count, so a completed finalize is never repeated; see
  "First run" below).
- **Best-effort, non-fatal** attempt to seed the LDAP auth strategy directly
  into the database (see “Active Directory login” below).

## Ports

| Host port | Container | Purpose |
| --------- | -------- | --------------------------------- |
| `8083` (`ccdc_wikijs_port`) | `wiki:3000` | Wiki.js HTTP (primary) |
| `3000` | `wiki:3000` | Wiki.js HTTP (convenience/direct) |

URL: **`http://<wiki01-ip>:8083/`**

## First run — the local admin is created automatically

Wiki.js 2.x (stable image) does **not** create the admin account from
environment variables — there is no working `WIKI_ADMIN_EMAIL` in this image,
and it would otherwise require the one-time browser **Administrator Setup**
wizard. This role automates that wizard instead: once Wiki.js is reachable, it
counts existing users (0 means not yet finalized) and, if so, `POST`s to
`/finalize` with:

- **Administrator Email** — `admin@prccdc.local` (`ccdc_wikijs_admin_email`)
- **Password** — `PRccdc-Wiki-2026!` (`ccdc_wikijs_admin_password`)
- **Site URL** — derived from `ccdc_wikijs_host`/`ccdc_wikijs_site_url`, or the
  VM's primary IP + `ccdc_wikijs_port` if left blank

This is what actually creates the Wiki.js database schema (including the
`authentication` table), the same as completing the wizard by hand. The task
is idempotent — admin row count, not table presence, is the finalized check
(the `users` table exists empty before setup, so table presence alone would
false-positive on a fresh deploy) — and never re-runs once an admin exists. No
manual browser step is needed; log in directly with the credentials above.

## Active Directory (LDAP) login

Wiki.js keeps auth strategies **in its database**, configured through the admin
UI, so fully unattended LDAP is not trivial. This role provides both paths:

### (a) Documented manual config — reliable, always available

The complete, ready-to-paste settings live in **`files/ldap-config.md`** (also
copied to `/opt/ccdc/wikijs/ldap-config.md` on the VM). Summary of the exact
Wiki.js **LDAP / Active Directory** strategy values:

| Field | Value |
| --- | --- |
| Display Name | `Active Directory` |
| LDAP URL | `ldap://10.2.10.10:389` (`ccdc_wikijs_ldap_host` / `_port`; `ldaps://…:636` for TLS) |
| Admin Bind DN | `cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local` |
| Admin Bind Credentials | `PRccdc-Svc-2026!` (`ccdc_wikijs_ldap_bind_password`) |
| Search Base | `ou=CCDC,dc=prccdc,dc=local` (or `cn=Users,dc=prccdc,dc=local`) |
| Search Filter | `(&(objectClass=user)(sAMAccountName={{username}}))` |
| Unique ID mapping | `objectGUID` (or `sAMAccountName`) |
| Email mapping | `mail` |
| Display Name mapping | `displayName` (falls back to `cn`) |
| Self-registration | on (auto-creates the wiki account on first AD login) |

> The search-filter token Wiki.js actually parses is `{{username}}` (some docs
> call it `{{input}}`). Use `{{username}}` as shown.

In the UI: **Administration → Authentication → + Add Strategy → LDAP / Active
Directory**, paste the values, **Apply**, **Save**, log out. AD users then sign
in with their `sAMAccountName` (e.g. `athompson`) and AD password.

### (b) Best-effort DB seed — automatic when possible, never fatal

When `ccdc_wikijs_seed_ldap: true` (default), the role checks whether the
Wiki.js `authentication` table exists and, if so, upserts the AD strategy row
(the exact settings above) with `psql` inside the `db` container, then restarts
the `wiki` service so it reloads the strategy. This is intentionally **fragile
and non-fatal**:

- On a fresh deploy the setup wizard has not run yet, so the `authentication`
  table does **not** exist — the seed is **skipped** and you configure LDAP via
  the UI using `ldap-config.md`.
- Re-running the role **after** completing the wizard will apply the seed. The
  task never fails the play regardless of outcome.

Set `ccdc_wikijs_seed_ldap: false` to skip the seed entirely and rely solely on
the documented manual step.

## Key variables (`defaults/main.yml`)

| Variable | Default | Purpose |
| --- | --- | --- |
| `ccdc_wikijs_stack_dir` | `/opt/ccdc/wikijs` | Compose stack directory |
| `ccdc_wikijs_port` | `8083` | Host port → wiki `:3000` |
| `ccdc_wikijs_image` | `ghcr.io/requarks/wiki:2` | Wiki.js image |
| `ccdc_wikijs_db_image` | `postgres:16` | Database image |
| `ccdc_wikijs_db_name` | `wiki` | Postgres DB name |
| `ccdc_wikijs_db_user` | `wikijs` | Postgres user |
| `ccdc_wikijs_db_password` | `PRccdc-WikiDB-2026!` | Postgres password |
| `ccdc_wikijs_admin_email` | `admin@prccdc.local` | Local admin (first-run wizard) |
| `ccdc_wikijs_admin_password` | `PRccdc-Wiki-2026!` | Local admin password |
| `ccdc_wikijs_ldap_host` | `10.2.10.10` | Domain controller (LDAP) |
| `ccdc_wikijs_ldap_port` | `389` | LDAP port (`636` for TLS) |
| `ccdc_wikijs_ldap_tls` | `false` | Use LDAPS |
| `ccdc_wikijs_ldap_bind_dn` | `cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local` | Bind DN |
| `ccdc_wikijs_ldap_bind_password` | `PRccdc-Svc-2026!` | Bind password |
| `ccdc_wikijs_ldap_search_base` | `ou=CCDC,dc=prccdc,dc=local` | Search base |
| `ccdc_wikijs_ldap_user_filter` | `(&(objectClass=user)(sAMAccountName={{username}}))` | User filter |
| `ccdc_wikijs_ldap_mapping_uid` | `objectGUID` | Unique-ID mapping |
| `ccdc_wikijs_ldap_mapping_email` | `mail` | Email mapping |
| `ccdc_wikijs_ldap_mapping_display_name` | `displayName` | Display-name mapping |
| `ccdc_wikijs_ldap_self_registration` | `true` | Auto-create AD users |
| `ccdc_wikijs_seed_ldap` | `true` | Attempt best-effort DB seed |

**Override the passwords for any real deployment** — all are settable through
Ludus `role_vars`. The bind credentials should match the `svc_ldap` account the
`ccdc_ad_accounts` role creates on the DC.

Example Ludus `role_vars`:

```yaml
- vm_name: wiki01
  roles:
    - ccdc_wikijs
  role_vars:
    ccdc_wikijs_port: 8083
    ccdc_wikijs_ldap_host: "10.2.10.10"
    ccdc_wikijs_ldap_bind_password: "Bind-Only-Reader-99!"
    ccdc_wikijs_admin_password: "S3cret-Wiki!"
```

## Verify

```bash
# Wiki.js answers (302 redirect to /login or 200 once set up):
curl -I http://<wiki01-ip>:8083/

# On the VM, watch the stack:
cd /opt/ccdc/wikijs && docker compose ps
docker compose logs -f wiki

# Confirm the LDAP bind account resolves an AD user (optional; needs ldap-utils):
ldapsearch -x -H ldap://10.2.10.10:389 \
  -D "cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local" \
  -w 'PRccdc-Svc-2026!' -b "ou=CCDC,dc=prccdc,dc=local" \
  "(&(objectClass=user)(sAMAccountName=athompson))" dn mail displayName
```

A `curl -I` returning an HTTP status line (typically `302` before setup, `200`
after) confirms Wiki.js is serving. After configuring LDAP, the login page
shows an **Active Directory** option and domain users can sign in.
