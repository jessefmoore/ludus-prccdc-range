# ccdc.ccdc_devtools

Deploys a developer-tooling stack for a CCDC range on a single Debian Linux VM
(Debian 12 substitutes for Debian 13) using **Docker Compose**:

- **[Gitea](https://gitea.io/)** — a lightweight self-hosted Git server
  (SQLite backend, no external DB).
- **[JFrog Artifactory OSS](https://jfrog.com/community/open-source/)** — a
  binary/artifact repository.

Docker and the `docker compose` plugin are assumed to be **already installed**
(the VM runs `geerlingguy.docker` before this role). This role does not install
Docker and does not use `community.docker`.

## What it does

- Creates the stack directory `/opt/ccdc/devtools` (mode `0755`).
- Templates `docker-compose.yml` (Gitea + Artifactory, `restart: unless-stopped`,
  named volumes for persistence).
- Runs `docker compose up -d` in that directory (idempotent).
- Waits for Gitea, then bootstraps an initial **admin** user via
  `gitea admin user create` (idempotent — checks `gitea admin user list` first).
- Adds an **Active Directory / LDAP (BindDN)** auth source named `PRCCDC-AD` via
  `gitea admin auth add-ldap`, so AD users in `prccdc.local` can log into Gitea
  with their domain credentials (idempotent — checks `gitea admin auth list`
  first and only adds when the source is absent).

## Ports

| Host port | Container | Service                                  |
|-----------|-----------|------------------------------------------|
| `3000`    | `3000`    | Gitea web UI (`ccdc_devtools_gitea_port`) |
| `2222`    | `22`      | Gitea SSH (`ccdc_devtools_gitea_ssh_port`)|
| `8082`    | `8082`    | Artifactory UI/API (`ccdc_devtools_artifactory_port`) |
| `8081`    | `8081`    | Artifactory service (`ccdc_devtools_artifactory_router_port`) |

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
| `ccdc_devtools_artifactory_port`            | `8082`                                               | Host port -> Artifactory UI/API.             |
| `ccdc_devtools_artifactory_router_port`     | `8081`                                               | Host port -> Artifactory service.            |
| `ccdc_devtools_artifactory_image`           | `releases-docker.jfrog.io/jfrog/artifactory-oss:latest` | Artifactory OSS image.                   |

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

- **Artifactory:** `http://<dev01-ip>:8082/ui`
  Default first-boot credentials are `admin` / `password` (you are prompted to
  change the password on first login).
  **Note:** Artifactory OSS needs several GB of RAM and takes **1-2 minutes** to
  finish initialising on first boot before the UI responds — be patient.

## Verify

On the VM:

```bash
cd /opt/ccdc/devtools && docker compose ps
```

Both `ccdc_gitea` and `ccdc_artifactory` should be `Up`. Then:

```bash
curl -I http://localhost:3000              # Gitea -> HTTP 200/303
curl -I http://localhost:8082/ui/          # Artifactory -> HTTP 200 (after first-boot warm-up)
```

## Lighter alternative: Sonatype Nexus 3

Artifactory OSS is memory-hungry. If the range VM is RAM-constrained, the
templated `docker-compose.yml` includes a **commented-out** `nexus`
(`sonatype/nexus3:latest`) service block. Comment out `artifactory`, uncomment
`nexus` and its `nexus_data` volume, then `docker compose up -d`. Nexus serves
its UI/repos on port `8081`; its generated admin password lives at
`/nexus-data/admin.password`:

```bash
docker exec ccdc_nexus cat /nexus-data/admin.password
```
