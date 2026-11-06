# ccdc.ccdc_sso

Deploys an SSO / identity service plus two demo backend APIs on a single Ubuntu
22.04 VM using Docker Compose, as a CCDC range target:

- **Keycloak** (`quay.io/keycloak/keycloak:latest`, `start-dev`) backed by
  **PostgreSQL** (`postgres:16`) for identity / single sign-on.
- **waitAPI** — an `nginx:alpine` container serving a static JSON array of park
  rides and their estimated wait times.
- **RideAPI** — an `nginx:alpine` container serving a static JSON catalog of
  rides (id, name, type, capacity, status).

Docker and the `docker compose` plugin are assumed already installed (the VM
runs `geerlingguy.docker` before this role). This role does **not** install
Docker and does **not** use the `community.docker` collection.

## What it does

- Creates the stack directory `/opt/ccdc/sso` (mode 0755) with `waitapi/` and
  `rideapi/` subdirectories.
- Templates `docker-compose.yml`, the two JSON payloads, and a small nginx
  `default.conf` (returns the JSON as `application/json`, plus a `/healthz`).
- Copies `keycloak-realm-import.json` (a reference-only realm doc, not
  applied) into the stack dir.
- Runs `docker compose up -d` from the stack dir (idempotent; re-running only
  reports "changed" when a container is actually created/recreated/started).
- When `ccdc_sso_ad_ldap_enabled` is true (the default), automatically wires
  Keycloak to the `prccdc.local` AD domain: creates the `ccdc` realm, adds an
  `ad-ldap` user-federation provider via `kcadm` (`kc-federate.sh`, idempotent),
  and triggers a user sync — see "Active Directory / LDAP user federation"
  below.

## Ports

| Service   | Container port | Host port (default)        | Purpose                          |
|-----------|----------------|----------------------------|----------------------------------|
| Keycloak  | 8080           | `ccdc_sso_keycloak_port` = `8080` | SSO admin console + OIDC   |
| waitAPI   | 80             | `ccdc_sso_waitapi_port`  = `8081` | Ride wait-time JSON        |
| RideAPI   | 80             | `ccdc_sso_rideapi_port`  = `8082` | Ride catalog JSON          |
| PostgreSQL| 5432           | (internal only)            | Keycloak database                |

## Endpoints

Replace `<sso01-ip>` with the VM's address.

- Keycloak admin console: <http://<sso01-ip>:8080/>
  - Username: `admin` (`ccdc_sso_keycloak_admin`)
  - Password: `PRccdc-Keycloak-2026!` (`ccdc_sso_keycloak_admin_password`)
- waitAPI: <http://<sso01-ip>:8081/>
- RideAPI: <http://<sso01-ip>:8082/>

## Variables (`defaults/main.yml`)

All variables are namespaced `ccdc_sso_` (Ludus shares role_vars across roles).

| Variable                            | Default                    | Description                                  |
|-------------------------------------|----------------------------|----------------------------------------------|
| `ccdc_sso_stack_dir`                | `/opt/ccdc/sso`            | Compose stack directory.                     |
| `ccdc_sso_postgres_image`           | `postgres:16`              | Keycloak database image.                     |
| `ccdc_sso_keycloak_image`           | `quay.io/keycloak/keycloak:latest` | Keycloak image.                     |
| `ccdc_sso_api_image`                | `nginx:alpine`             | Image for both demo APIs.                    |
| `ccdc_sso_postgres_db`              | `keycloak`                 | Postgres database name.                      |
| `ccdc_sso_postgres_user`            | `keycloak`                 | Postgres user.                               |
| `ccdc_sso_postgres_password`        | `PRccdc-KcDB-2026!`        | Postgres password.                           |
| `ccdc_sso_keycloak_admin`           | `admin`                    | Keycloak bootstrap admin username.           |
| `ccdc_sso_keycloak_admin_password`  | `PRccdc-Keycloak-2026!`    | Keycloak bootstrap admin password.           |
| `ccdc_sso_keycloak_port`            | `8080`                     | Host port for the Keycloak console.          |
| `ccdc_sso_waitapi_port`             | `8081`                     | Host port for waitAPI.                       |
| `ccdc_sso_rideapi_port`             | `8082`                     | Host port for RideAPI.                       |
| `ccdc_sso_ad_ldap_enabled`          | `true`                     | Auto-wire Keycloak to AD via `kc-federate.sh`. |
| `ccdc_sso_realm`                    | `ccdc`                     | Realm created for the AD-federated apps.     |
| `ccdc_sso_ldap_host`                | `10.50.10.10`              | AD DC / DNS server IP.                       |
| `ccdc_sso_ldap_port`                | `389`                      | LDAP port (389 = plaintext).                 |
| `ccdc_sso_ldap_users_dn`            | `dc=prccdc,dc=local`       | LDAP users DN searched by the federation provider. |
| `ccdc_sso_ldap_bind_dn`             | `cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local` | Bind DN (svc_ldap service account). |
| `ccdc_sso_ldap_bind_password`       | `PRccdc-Svc-2026!`         | Bind password (**override!**).               |

## Verify

From the VM (or any host that can reach it):

```bash
# Keycloak console reachable (302 redirect to /admin/ is expected)
curl -I http://<sso01-ip>:8080/

# Demo APIs return JSON
curl -s http://<sso01-ip>:8081/ | head        # waitAPI
curl -s http://<sso01-ip>:8082/ | head        # RideAPI
curl -s http://<sso01-ip>:8081/healthz        # -> ok

# Container status
cd /opt/ccdc/sso && docker compose ps
```

Keycloak takes ~20-40s after `up -d` to finish its first-boot DB migration
before the console answers.

## Active Directory / LDAP user federation (automatic by default)

When `ccdc_sso_ad_ldap_enabled` is `true` (the default), the role wires
Keycloak to the `prccdc.local` AD domain with no manual steps:

1. Renders `keycloak-ad-ldap.json` — the `ad-ldap` federation component
   definition (vendor `Active Directory`, bind DN `svc_ldap`, `READ_ONLY` edit
   mode, username attribute `sAMAccountName`, UUID attribute `objectGUID`).
2. Renders and runs `kc-federate.sh`, which uses `kcadm` to idempotently
   create the `{{ ccdc_sso_realm }}` realm (default `ccdc`), add the `ad-ldap`
   provider if it's not already present, and trigger a full user sync.
3. This step is **non-fatal** (`failed_when: false`): on a from-scratch
   deploy, Keycloak or AD may still be warming up, so a failure here doesn't
   abort the play — a re-run or the next deploy completes it.

AD users (e.g. `athompson`) can then authenticate against the `ccdc` realm —
log into the admin console's realm user list to confirm the sync, or request
an OIDC token via the realm's token endpoint
(`/realms/{{ ccdc_sso_realm }}/protocol/openid-connect/token`) with a
password grant.

Domain context (see `roles/ROLE_CONVENTIONS.md`):

- Domain: `prccdc.local` (NetBIOS `PRCCDC`), base DN `dc=prccdc,dc=local`.
- Bind account: `svc_ldap` (created by the `ccdc_ad_accounts` role).

### Disabling automatic federation / doing it by hand

Set `ccdc_sso_ad_ldap_enabled: false` to skip the automated steps entirely.
`files/keycloak-realm-import.json` is also copied to
`/opt/ccdc/sso/keycloak-realm-import.json` as a plain reference realm doc (not
applied) if you'd rather configure federation manually through the admin
console (*User federation* > *Add provider* > *LDAP*) or via *Realm settings >
Partial import*. Prefer LDAPS (636) with a trusted certificate for anything
beyond a throwaway lab — the automated path uses plaintext LDAP (389) by
default via `ccdc_sso_ldap_port`.
