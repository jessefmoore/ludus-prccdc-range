# ccdc.ccdc_devtools

Deploys a developer-tooling stack for a CCDC range on a single Debian Linux VM
(Debian 12 substitutes for Debian 13) using **Docker Compose**:

- **[Gitea](https://gitea.io/)** — a lightweight self-hosted Git server
  (SQLite backend, no external DB).
- An artifact repository — **[Sonatype Nexus 3](https://www.sonatype.com/products/sonatype-nexus-repository)**
  by default, or **[JFrog Artifactory OSS](https://jfrog.com/community/open-source/)**
  if you opt in. Both are selected by the single `ccdc_devtools_artifact_backend`
  variable; the templated compose file renders whichever one is chosen.

Docker and the `docker compose` plugin are assumed to be **already installed**
(the VM runs `geerlingguy.docker` before this role). This role does not install
Docker and does not use `community.docker`.

## What it does

- Creates the stack directory `/opt/ccdc/devtools` (mode `0755`).
- Templates `docker-compose.yml` (Gitea + the selected artifact backend,
  `restart: unless-stopped`, named volumes for persistence).
- Runs `docker compose up -d` in that directory (idempotent).
- Waits for Gitea, then bootstraps an initial **admin** user via
  `gitea admin user create` (idempotent — checks `gitea admin user list` first).
- Adds an **Active Directory / LDAP (BindDN)** auth source named `PRCCDC-AD` via
  `gitea admin auth add-ldap`, so AD users in `prccdc.local` can log into Gitea
  with their domain credentials (idempotent — checks `gitea admin auth list`
  first and only adds when the source is absent).
- When running the Nexus backend (the default), waits for and reports Nexus's
  randomly-generated first-boot admin password.

## Ports

| Host port | Container | Service                                  |
|-----------|-----------|------------------------------------------|
| `3000`    | `3000`    | Gitea web UI (`ccdc_devtools_gitea_port`) |
| `2222`    | `22`      | Gitea SSH (`ccdc_devtools_gitea_ssh_port`)|
| `8082`    | `8081` (Nexus) / `8082` (Artifactory) | Artifact repo UI/API (`ccdc_devtools_artifactory_port`) |
| `8081`    | `8081`    | Artifactory legacy service port (`ccdc_devtools_artifactory_router_port`, Artifactory backend only) |

## Variables (`defaults/main.yml`)

| Variable                                    | Default                                              | Description                                  |
|---------------------------------------------|------------------------------------------------------|----------------------------------------------|
| `ccdc_devtools_dir`                         | `/opt/ccdc/devtools`                                 | Stack directory.                             |
| `ccdc_devtools_gitea_port`                  | `3000`                                               | Host port -> Gitea web.                      |
| `ccdc_devtools_gitea_ssh_port`              | `2222`                                               | Host port -> Gitea SSH.                      |
| `ccdc_devtools_gitea_root_url`              | `http://<host-ip>:3000/`                             | Gitea `ROOT_URL` for clone/webhook links.    |
| `ccdc_devtools_gitea_image`                 | `gitea/gitea:1.22`                                   | Gitea image tag.                             |
| `ccdc_devtools_gitea_admin_user`            | `gitadmin`                                           | Initial Gitea admin username.                |
| `ccdc_devtools_gitea_admin_password`        | `PRccdc-Gitea-2026!`                                 | Initial Gitea admin password (**override!**).|
| `ccdc_devtools_gitea_admin_email`           | `gitadmin@prccdc.local`                              | Initial Gitea admin email.                   |
| `ccdc_devtools_ldap_host`                   | `10.2.10.10`                                         | Domain controller / LDAP server IP.          |
| `ccdc_devtools_ldap_port`                   | `389`                                                | LDAP port (389 = plaintext).                 |
| `ccdc_devtools_ldap_bind_dn`                | `cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local` | Bind DN (svc_ldap service account).   |
| `ccdc_devtools_ldap_bind_password`          | `PRccdc-Svc-2026!`                                   | Bind password (**override!**).               |
| `ccdc_devtools_ldap_base_dn`                | `dc=prccdc,dc=local`                                 | User search base DN.                         |
| `ccdc_devtools_ldap_source_name`            | `PRCCDC-AD`                                          | Gitea auth source name (idempotency key).    |
| `ccdc_devtools_artifact_backend`            | `nexus`                                              | `nexus` (default, light) or `artifactory` (heavy, needs 12 GB dev01). |
| `ccdc_devtools_artifactory_port`            | `8082`                                               | Host port -> artifact repo UI/API (either backend). |
| `ccdc_devtools_artifactory_router_port`     | `8081`                                               | Host port -> Artifactory's legacy service port (Artifactory only). |
| `ccdc_devtools_artifactory_image`           | `releases-docker.jfrog.io/jfrog/artifactory-oss:latest` | Artifactory OSS image.                   |
| `ccdc_devtools_nexus_image`                 | `sonatype/nexus3:latest`                             | Nexus image.                                 |

## Accessing the services

- **Gitea:** `http://<dev01-ip>:3000`
  Log in with `ccdc_devtools_gitea_admin_user` / `ccdc_devtools_gitea_admin_password`
  (defaults `gitadmin` / `PRccdc-Gitea-2026!`).
  Clone over SSH uses port `2222`, e.g.
  `git clone ssh://git@<dev01-ip>:2222/gitadmin/repo.git`.

### Logging in as an Active Directory user

Gitea is wired to the `prccdc.local` domain via the `PRCCDC-AD` LDAP auth
source. A domain user (for example a member of `CCDC-Employees`) logs in on the
normal Gitea sign-in page:

1. Browse to `http://<dev01-ip>:3000` and click **Sign In**.
2. Enter the AD **sAMAccountName** (the short logon name, e.g. `jdoe` — not the
   `PRCCDC\jdoe` or UPN form) and the domain password.
3. Gitea binds to the DC with the `svc_ldap` service account, finds the user via
   `(&(objectClass=user)(sAMAccountName=%s))`, and — on first successful login —
   auto-creates a local Gitea account populated from the directory
   (`givenName`, `sn`, `mail`). `--synchronize-users` keeps those attributes in
   sync on Gitea's periodic LDAP sync.

Verify the source exists on the VM with:

```bash
docker exec -u git ccdc_gitea gitea admin auth list
```

You should see a row named `PRCCDC-AD` of type `LDAP (via BindDN)`. If AD logins
fail, confirm the DC is reachable on `389`, the `svc_ldap` bind DN/password are
correct, and the user actually exists under `dc=prccdc,dc=local`.

- **Nexus (default backend):** `http://<dev01-ip>:8082/`
  User `admin`; the first-boot password is auto-generated inside the container
  and reported by the role (it also waits for the password file to appear).
  Retrieve it manually any time with:

  ```bash
  docker exec ccdc_nexus cat /nexus-data/admin.password
  ```

  Nexus forces a password change on first login.

- **Artifactory (if `ccdc_devtools_artifact_backend: artifactory`):**
  `http://<dev01-ip>:8082/ui`. Default first-boot credentials are `admin` /
  `password` (you are prompted to change the password on first login).
  **Note:** Artifactory OSS needs several GB of RAM (the role docs recommend
  bumping dev01 to 12 GB) and takes **1-2 minutes** to finish initialising on
  first boot before the UI responds — be patient.

## Verify

On the VM:

```bash
cd /opt/ccdc/devtools && docker compose ps
```

`ccdc_gitea` plus either `ccdc_nexus` (default) or `ccdc_artifactory` should be
`Up`. Then:

```bash
curl -I http://localhost:3000              # Gitea -> HTTP 200/303
curl -I http://localhost:8082/             # Nexus/Artifactory -> HTTP 200 (after first-boot warm-up)
```

## Switching to JFrog Artifactory

Nexus is the default because Artifactory OSS's ~6 JVM microservices are heavy
and, in validation, didn't reliably stay up sharing RAM with Gitea on an 8 GB
VM. To switch back to Artifactory: set `ccdc_devtools_artifact_backend:
artifactory` in `ccdc-range.yml` (role_vars for dev01), raise dev01 to
`ram_gb: 12, ram_min_gb: 12`, and redeploy. The compose template renders
whichever backend the variable selects — no manual compose editing needed.
