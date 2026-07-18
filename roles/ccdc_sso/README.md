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
- Copies `keycloak-realm-import.json` (optional AD/LDAP federation reference)
  into the stack dir.
- Runs `docker compose up -d` from the stack dir (idempotent; re-running only
  reports "changed" when a container is actually created/recreated/started).

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

## Optional: AD / LDAP user federation

`files/keycloak-realm-import.json` is a **reference** realm document that adds
an LDAP user-federation provider pointing at the AD domain. It is copied to
`/opt/ccdc/sso/keycloak-realm-import.json` but is **not** applied automatically
and is not required to succeed at deploy.

Domain context (see `roles/ROLE_CONVENTIONS.md`):

- Domain: `prccdc.local` (NetBIOS `PRCCDC`), base DN `dc=prccdc,dc=local`.
- Users container: `cn=Users,dc=prccdc,dc=local`.
- Bind account: `svc_ldap` (created by the `ccdc_ad_accounts` role; supply its
  password out-of-band).

To wire it up, either:

1. **Admin console:** log in, create/select a realm, go to *User federation*
   > *Add provider* > *LDAP*, and enter:
   - Vendor: `Active Directory`
   - Connection URL: `ldap://dc01.prccdc.local:389` (or `ldaps://...:636`)
   - Users DN: `cn=Users,dc=prccdc,dc=local`
   - Bind type: `simple`, Bind DN: `cn=svc_ldap,cn=Users,dc=prccdc,dc=local`,
     Bind credential: `<svc_ldap password>`
   - Username LDAP attribute: `sAMAccountName`, UUID attribute: `objectGUID`
   - Edit mode: `READ_ONLY` (safe for a lab), then *Test connection* /
     *Test authentication* and *Save* > *Sync all users*.

2. **Import the reference file:** open the JSON, replace `BIND_PASSWORD_HERE`
   and adjust the `connectionUrl`/DNs, then use *Realm settings > Partial
   import*, or restart Keycloak with `--import-realm` and the file staged in
   `/opt/keycloak/data/import`.

`READ_ONLY` edit mode prevents Keycloak from writing back to AD. Prefer LDAPS
(636) with a trusted certificate for anything beyond a throwaway lab.
