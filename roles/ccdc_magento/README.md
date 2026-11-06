# ccdc.ccdc_magento

Deploys **Magento** (open-source e-commerce) onto a Linux VM (Ubuntu 22.04,
standing in for Rocky) as a CCDC range target, using Docker Compose:

- `alexcheng/magento2:2.2` — a self-contained Magento 2.2 image (Apache + PHP +
  Magento). The `:2.2` tag uses MySQL-based catalog search, so **no
  Elasticsearch/OpenSearch container is required** — far more reliable to
  deploy than the stock Magento 2.4 stack.
- `mysql:5.7` — the database backend (persisted volume).

(Bitnami removed its Magento/MariaDB/OpenSearch images from Docker Hub in
2025, which is why this role runs the `alexcheng` image + plain MySQL instead
of a Bitnami all-in-one stack.)

Docker and the `docker compose` plugin are assumed to be **already installed**
by `geerlingguy.docker` (listed before this role on the VM). This role does not
install Docker.

## What it does

1. Creates the stack directory `/opt/ccdc/magento` (mode `0755`).
2. Templates `docker-compose.yml` into that directory.
3. Runs `docker compose up -d` (idempotent: it only runs when the compose file
   changed or the `magento` container is not already running).
4. Waits for the `db` container to accept connections.
5. Runs `bin/magento setup:install` inside the `magento` container if it is
   not already installed (keyed on `app/etc/env.php`) — the `alexcheng` image
   does not reliably auto-install on its own.

## Ports

| Host port | Container | Protocol | Purpose                           |
|-----------|-----------|----------|------------------------------------|
| `8085`    | `80`      | TCP      | Magento storefront / admin (HTTP) |

Host port is configurable (`ccdc_magento_port`).

## Variables (`defaults/main.yml`)

| Variable                          | Default                          | Description                                                   |
|------------------------------------|-----------------------------------|----------------------------------------------------------------|
| `ccdc_magento_stack_dir`          | `/opt/ccdc/magento`              | Compose stack directory.                                      |
| `ccdc_magento_admin_user`         | `admin`                          | Magento admin (back office) username.                        |
| `ccdc_magento_admin_password`     | `PRccdc-Magento-2026!`           | Magento admin password.                                      |
| `ccdc_magento_admin_email`        | `admin@prccdc.local`             | Magento admin email.                                         |
| `ccdc_magento_admin_firstname`    | `PRCCDC`                         | Admin first name.                                            |
| `ccdc_magento_admin_lastname`     | `Admin`                          | Admin last name.                                             |
| `ccdc_magento_host`               | `localhost`                      | **Set to the shop VM IP/hostname at deploy** (base URL).     |
| `ccdc_magento_port`               | `8085`                           | Host HTTP port.                                               |
| `ccdc_magento_language`           | `en_US`                          | Locale baked in at install.                                   |
| `ccdc_magento_timezone`           | `America/Los_Angeles`            | Timezone baked in at install.                                 |
| `ccdc_magento_currency`           | `USD`                            | Currency baked in at install.                                 |
| `ccdc_magento_backend_frontname`  | `admin`                          | Admin URL path segment.                                       |
| `ccdc_magento_db_name`            | `magento2`                       | MySQL database name.                                          |
| `ccdc_magento_db_root_password`   | `magento2`                       | MySQL root password (the installer connects to `db` as root). |
| `ccdc_magento_image`              | `alexcheng/magento2:2.2`         | Magento image tag.                                            |
| `ccdc_magento_mysql_image`        | `mysql:5.7`                      | MySQL image tag.                                               |

Best-effort AD/LDAP integration values (`ccdc_magento_ldap_*`) are also defined
but not auto-applied — see "Active Directory / LDAP integration" below.

> **Important:** `ccdc_magento_host` is baked into Magento's base URL on first
> boot. If you leave it as `localhost`, storefront and admin links will point at
> `localhost`. Set it to the shop VM's IP or DNS name (e.g. the shop01 address)
> when you deploy.

## First boot is slow — be patient

Magento's first-run provisioning (`setup:install`: schema install, static
content deploy) legitimately takes a few minutes, sometimes longer on a cold
cache. The storefront returns errors or 500s until the install finishes — this
is expected, not a failure.

## Access

- Storefront: `http://<shop01-ip>:8085`
- Admin panel: `http://<shop01-ip>:8085/admin`
- Admin credentials: `admin` / `PRccdc-Magento-2026!` (defaults above).

## Active Directory / LDAP integration for Magento

Magento has no first-party AD/LDAP login path on this image. Options, in
order of effort: a third-party Magento LDAP extension, or fronting the admin
panel with Keycloak SSO (`ccdc_sso`) via a reverse-proxy/SAML flow. Neither is
wired up automatically by this role; `ccdc_magento_ldap_*` vars document the
`svc_ldap` bind settings for whichever approach you pick.

## Verify

On the VM, from the stack directory:

```bash
cd /opt/ccdc/magento

# Both services should be listed; magento comes up after db.
docker compose ps

# Watch the Magento install/provisioning progress live.
docker compose logs -f magento
```

Once provisioning has finished, from a client:

```bash
curl -I http://<shop01-ip>:8085
```

A `200 OK` (or a `302` redirect to the base URL) confirms Magento is serving.
While it is still installing you will get connection resets or `503`/`500`
responses — wait and retry.
