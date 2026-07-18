# ccdc_data

Deploys a data-services stack on an Ubuntu 22.04 VM via Docker Compose for a
CCDC range:

- **MySQL 8** relational database (optionally seeded with a small sample schema)
- **MinIO** S3-compatible object storage with a pre-created bucket
- A one-shot **`minio/mc`** init container that creates the bucket and uploads a
  placeholder object

Docker and the `docker compose` plugin are assumed to be installed already
(`geerlingguy.docker` runs before this role). The role does **not** install
Docker and does **not** use `community.docker`.

Stack directory: `/opt/ccdc/data` (compose file + `seed.sql`).

## Exposed services

Replace `<data01-ip>` with the VM's IP address.

### MySQL — `<data01-ip>:3306`

| Setting        | Default value             | Variable                          |
| -------------- | ------------------------- | --------------------------------- |
| Host port      | `3306`                    | `ccdc_data_mysql_port`            |
| Database       | `appdb`                   | `ccdc_data_mysql_database`        |
| App user       | `appuser`                 | `ccdc_data_mysql_user`            |
| App password   | `PRccdc-MySQL-2026!`      | `ccdc_data_mysql_password`        |
| Root password  | `PRccdc-MySQL-Root-2026!` | `ccdc_data_mysql_root_password`   |

Seeded (when `ccdc_data_mysql_seed: true`, the default) with `customers` and
`orders` sample tables containing a few fake rows. The seed runs only on the
**first** initialization of the MySQL data volume.

### MinIO — console `http://<data01-ip>:9001`, S3 API `http://<data01-ip>:9000`

| Setting        | Default value          | Variable                          |
| -------------- | ---------------------- | --------------------------------- |
| API port       | `9000`                 | `ccdc_data_minio_api_port`        |
| Console port   | `9001`                 | `ccdc_data_minio_console_port`    |
| Root user      | `ccdcadmin`            | `ccdc_data_minio_root_user`       |
| Root password  | `PRccdc-Minio-2026!`   | `ccdc_data_minio_root_password`   |
| Bucket         | `company-data`         | `ccdc_data_minio_bucket`          |

The `company-data` bucket is created on first startup and contains a
`placeholder.txt` object.

## Variables

All tunables are namespaced with `ccdc_data_` and live in
[`defaults/main.yml`](defaults/main.yml). Override them via `role_vars` in your
Ludus range config. Change the passwords for anything beyond a throwaway lab.

## Verify

```bash
# On the VM: all three containers present (mysql + minio Up, minio-mc Exited 0)
cd /opt/ccdc/data && docker compose ps

# MySQL: connect and list the seeded tables (from the VM or a client host)
mysql -h <data01-ip> -u appuser -p'PRccdc-MySQL-2026!' appdb -e 'SHOW TABLES; SELECT * FROM customers;'

# MinIO S3 API is up
curl -I http://<data01-ip>:9000/minio/health/live

# MinIO console: browse to http://<data01-ip>:9001 and log in with
#   user: ccdcadmin   password: PRccdc-Minio-2026!
# then confirm the "company-data" bucket exists with placeholder.txt inside.
```
