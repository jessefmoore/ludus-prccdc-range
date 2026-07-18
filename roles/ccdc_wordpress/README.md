# ccdc.ccdc_wordpress

Installs **WordPress** on a **Windows Server 2022** VM for the CCDC range using a
[XAMPP](https://www.apachefriends.org/) stack (Apache + PHP + MariaDB) deployed
via Chocolatey. WordPress on Windows is finicky; XAMPP bundles a known-good
Apache/PHP/MariaDB combo, so this is the most reliable approach for a lab.

## What it does

1. Installs XAMPP (`xampp-80`, PHP 8.0) via `chocolatey.chocolatey.win_chocolatey`
   into `C:\xampp`.
2. Downloads `https://wordpress.org/latest.zip` to `C:\temp\wordpress.zip` and
   extracts it into `C:\xampp\htdocs\`, giving a site at
   `C:\xampp\htdocs\wordpress`. Download/extract are guarded by a `win_stat`
   check so re-runs are no-ops.
3. Registers **Apache** and **MariaDB** as Windows services using XAMPP's
   `apache_installservice.bat` / `mysql_installservice.bat`, then ensures both
   are **started** and set to **auto-start** so they survive reboots.
4. Creates the WordPress **database**, **user**, and **grants** in MariaDB via
   the bundled `mysql.exe` CLI (`CREATE DATABASE/USER IF NOT EXISTS` + `GRANT`,
   all idempotent).
5. Templates `wp-config.php` into the WordPress directory with the DB
   credentials and salts.
6. Installs and pre-configures the **authLdap** plugin so AD users
   (`prccdc.local`) log in with their domain accounts — see
   [Active Directory / LDAP authentication](#active-directory--ldap-authentication).
7. Opens the **Windows Firewall** for inbound TCP 80.

## Ports

| Port | Protocol | Purpose             |
|------|----------|---------------------|
| 80   | TCP      | Apache HTTP (site)  |

## URL

    http://<web01-ip>/wordpress

## Variables (`defaults/main.yml`)

| Variable                            | Default              | Description                                       |
|-------------------------------------|----------------------|---------------------------------------------------|
| `ccdc_wordpress_choco_package`      | `xampp-80`           | Chocolatey XAMPP package (bundles PHP 8.0).        |
| `ccdc_wordpress_xampp_root`         | `C:\xampp`           | XAMPP install root.                                |
| `ccdc_wordpress_docroot`            | `C:\xampp\htdocs`    | Apache document root.                              |
| `ccdc_wordpress_site_dir`           | `wordpress`          | Site subfolder under the docroot.                 |
| `ccdc_wordpress_download_url`       | `.../latest.zip`     | WordPress archive URL (pin for a repeatable lab). |
| `ccdc_wordpress_db_name`            | `wordpress`          | WordPress database name.                           |
| `ccdc_wordpress_db_user`            | `wp_user`            | WordPress DB user.                                 |
| `ccdc_wordpress_db_password`        | `PRccdc-WP-2026!`    | WordPress DB user password.                        |
| `ccdc_wordpress_db_root_password`   | `` (empty)           | MariaDB root password (XAMPP default: none).       |
| `ccdc_wordpress_table_prefix`       | `wp_`                | WordPress table prefix.                            |
| `ccdc_wordpress_apache_service_name`| `Apache2.4`          | Registered Apache service name.                    |
| `ccdc_wordpress_mysql_service_name` | `mysql`              | Registered MariaDB service name.                   |
| `ccdc_wordpress_http_port`          | `80`                 | Firewall/HTTP port.                                |
| `ccdc_wordpress_ldap_enabled`       | `true`               | Install + configure authLdap for AD login.         |
| `ccdc_wordpress_ldap_plugin_url`    | `.../authldap...zip` | authLdap plugin archive URL.                       |
| `ccdc_wordpress_ldap_host`          | `10.2.10.10`         | Domain Controller / LDAP server.                   |
| `ccdc_wordpress_ldap_port`          | `389`                | LDAP port.                                         |
| `ccdc_wordpress_ldap_base_dn`       | `dc=prccdc,dc=local` | LDAP search base.                                  |
| `ccdc_wordpress_ldap_bind_dn`       | `cn=svc_ldap,...`    | Bind/search service account DN.                    |
| `ccdc_wordpress_ldap_bind_password` | `PRccdc-Svc-2026!`   | Bind account password.                             |
| `ccdc_wordpress_ldap_user_filter`   | `(&(objectClass=user)(sAMAccountName=%s))` | AD user search filter.       |
| `ccdc_wordpress_ldap_default_role`  | `subscriber`         | WordPress role for authenticated AD users.         |

## Database credentials

| Field    | Value                                |
|----------|--------------------------------------|
| Host     | `localhost` (127.0.0.1:3306)         |
| Database | `wordpress`                          |
| User     | `wp_user`                            |
| Password | `PRccdc-WP-2026!`                    |

MariaDB `root` has **no password** by default under XAMPP. Override
`ccdc_wordpress_db_root_password` if you have set one.

## Manual finalize step (be honest: this is required)

This role installs and wires up WordPress, its database, and `wp-config.php`,
but it does **not** complete the WordPress **install wizard**. After the role
runs, browse to `http://<web01-ip>/wordpress` once and complete the one-page
setup (site title, admin username/password, admin email). That step writes the
admin account into the database and cannot be safely automated per-run without
clobbering an existing install. It is a single manual browser step.

## Active Directory / LDAP authentication

WordPress authenticates users against the CCDC Domain Controller so AD users in
`prccdc.local` log in with their **domain accounts** at
`http://<web01-ip>/wordpress/wp-login.php`. This is done with the
[**authLdap**](https://wordpress.org/plugins/authldap/) plugin, which the role:

1. Downloads (`authldap.latest-stable.zip`) and extracts into
   `wp-content\plugins\authldap\` (guarded by a `win_stat` check).
2. Pre-configures **and force-activates** via a Must-Use plugin at
   `wp-content\mu-plugins\ccdc-ldap-config.php` (templated from
   `templates/ccdc-ldap-config.php.j2`). The mu-plugin overrides
   `authLDAPOptions` on read (authoritative, no DB writes) and injects authLdap
   into the active-plugins list — so **no manual plugin setup is required**.

Set `ccdc_wordpress_ldap_enabled: false` to skip LDAP entirely.

### AD/LDAP settings (exact values)

| Setting        | Value                                                              |
|----------------|-------------------------------------------------------------------|
| LDAP URI       | `ldap://10.2.10.10:389/`                                          |
| DC host / port | `10.2.10.10` / `389`                                              |
| Base DN        | `dc=prccdc,dc=local`                                              |
| Bind account   | `svc_ldap`                                                        |
| Bind DN        | `cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local`       |
| Bind password  | `PRccdc-Svc-2026!` (`ccdc_wordpress_ldap_bind_password`)          |
| User filter    | `(&(objectClass=user)(sAMAccountName=%s))`                        |
| Name attr      | `displayName`                                                     |
| Mail attr      | `mail`                                                            |
| Group attr     | `memberOf`                                                        |
| Login attr     | `sAMAccountName`                                                  |
| Default role   | `subscriber` (`ccdc_wordpress_ldap_default_role`)                |

authLdap packs the bind account and search base into a single connection URI in
the plugin's documented format:
`ldap://<bindDN>:<bindPassword>@<host>:<port>/<baseDN>`. The `svc_ldap` service
account is created by the `ccdc_ad_accounts` role.

Any AD user that authenticates and has no explicit group→role mapping is created
in WordPress with the **subscriber** role. Group-based role mapping is disabled
so valid AD users are never rejected for group membership; raise a user's role in
`wp-admin` afterward if they need to author or administer.

### Verify an AD user can log in

1. Confirm the DC is reachable from the web VM (PowerShell):

   ```powershell
   Test-NetConnection 10.2.10.10 -Port 389
   ```

2. Browse to `http://<web01-ip>/wordpress/wp-login.php` and sign in as a
   **CCDC-Employees** AD user, e.g. username `athompson` with that account's AD
   password (`PRccdc-User-2026!` by default in `ccdc_ad_accounts`). A first
   successful login auto-provisions the WordPress account (role: subscriber) and
   lands on the dashboard/profile.

3. In `wp-admin → Users`, the AD user now appears in the list. If a login fails,
   temporarily set `'Debug' => true` in `ccdc-ldap-config.php` (or the plugin's
   Settings → authLdap page) and re-test to see the bind/search diagnostics.

The built-in local WordPress admin (created by the one-time install wizard, see
below) still works independently of AD, so you always have a fallback login.

## A note on salts

The `AUTH_KEY`/salts in `wp-config.php` are **static lab placeholders** so
deploys are reproducible. They are fine for a closed CCDC range but are **not
secret**. For any real/internet-facing deployment, replace them with unique
values from <https://api.wordpress.org/secret-key/1.1/salt/>.

## Verify

On the Windows VM, confirm both services are running:

```powershell
Get-Service Apache2.4, mysql
```

Both should report `Running`. Then check the site responds:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost/wordpress/ | Select-Object StatusCode
```

A `200` (or a `302` redirect to `/wp-admin/install.php` on first boot) confirms
Apache is serving WordPress. From another host: `curl -I http://<web01-ip>/wordpress/`.
