# ccdc.ccdc_magento

Deploys **Magento** (open-source e-commerce) onto a Linux VM (Ubuntu 22.04,
standing in for Rocky) as a CCDC range target, using the **Bitnami all-in-one
stack** run through Docker Compose:

- `bitnami/magento` — the Magento 2.4 application (Apache + PHP).
- `bitnami/mariadb` — the database backend (persisted volume).
- `bitnami/opensearch` — the search engine Magento 2.4 requires (single-node,
  security plugin disabled, modest heap).

Docker and the `docker compose` plugin are assumed to be **already installed**
by `geerlingguy.docker` (listed before this role on the VM). This role does not
install Docker.

## What it does

1. Sets `vm.max_map_count=262144` (persistent, via `ansible.posix.sysctl`) —
   OpenSearch will not start without it.
2. Creates the stack directory `/opt/ccdc/magento` (mode `0755`).
3. Templates `docker-compose.yml` into that directory.
4. Runs `docker compose up -d` (idempotent: it only runs when the compose file
   changed or the `magento` container is not already running).

## Ports

| Host port | Container | Protocol | Purpose                          |
|-----------|-----------|----------|----------------------------------|
| `8085`    | `8080`    | TCP      | Magento storefront / admin (HTTP)|
| `8443`    | `8443`    | TCP      | Magento HTTPS                    |

Host ports are configurable (`ccdc_magento_port`, `ccdc_magento_https_port`).
The Bitnami container runs non-root and listens internally on `8080`/`8443`.

## Variables (`defaults/main.yml`)

| Variable                          | Default                          | Description                                                   |
|-----------------------------------|----------------------------------|---------------------------------------------------------------|
| `ccdc_magento_stack_dir`          | `/opt/ccdc/magento`              | Compose stack directory.                                      |
| `ccdc_magento_admin_user`         | `admin`                          | Magento admin (back office) username.                        |
| `ccdc_magento_admin_password`     | `PRccdc-Magento-2026!`           | Magento admin password.                                      |
| `ccdc_magento_admin_email`        | `admin@prccdc.local`             | Magento admin email.                                         |
| `ccdc_magento_admin_firstname`    | `PRCCDC`                         | Admin first name.                                            |
| `ccdc_magento_admin_lastname`     | `Admin`                          | Admin last name.                                             |
| `ccdc_magento_host`               | `localhost`                      | **Set to the shop VM IP/hostname at deploy** (base URL).     |
| `ccdc_magento_port`               | `8085`                           | Host HTTP port.                                              |
| `ccdc_magento_https_port`         | `8443`                           | Host HTTPS port.                                             |
| `ccdc_magento_db_name`            | `bitnami_magento`                | MariaDB database name.                                       |
| `ccdc_magento_db_user`            | `bn_magento`                     | MariaDB application user.                                    |
| `ccdc_magento_db_password`        | `PRccdc-MagentoDB-2026!`         | MariaDB application user password.                          |
| `ccdc_magento_db_root_password`   | `PRccdc-MagentoRoot-2026!`       | MariaDB root password.                                       |
| `ccdc_magento_opensearch_heap`    | `512m`                           | OpenSearch JVM heap size.                                    |
| `ccdc_magento_image`              | `bitnami/magento:latest`         | Magento image tag.                                           |
| `ccdc_magento_mariadb_image`      | `bitnami/mariadb:latest`         | MariaDB image tag.                                           |
| `ccdc_magento_opensearch_image`   | `bitnami/opensearch:latest`      | OpenSearch image tag.                                        |

> **Important:** `ccdc_magento_host` is baked into Magento's base URL on first
> boot. If you leave it as `localhost`, storefront and admin links will point at
> `localhost`. Set it to the shop VM's IP or DNS name (e.g. the shop01 address)
> when you deploy.

## First boot is slow and RAM-hungry — be patient

Magento's first-run provisioning (schema install, static content deploy, index
build) legitimately takes **10-20+ minutes**, sometimes longer on a cold cache,
and it is memory-hungry. **Give the VM at least 8 GB of RAM** (OpenSearch alone
takes a ~512 MB heap plus overhead). The storefront returns errors or 500s until
the install finishes — this is expected, not a failure.

## Access

- Storefront: `http://<shop01-ip>:8085`
- Admin panel: `http://<shop01-ip>:8085/admin`
- Admin credentials: `admin` / `PRccdc-Magento-2026!` (defaults above).

## Verify

On the VM, from the stack directory:

```bash
cd /opt/ccdc/magento

# All three services should be listed; magento comes up last.
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
