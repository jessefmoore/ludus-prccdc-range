# CCDC Range — Service Validation Status

Validated over the range WireGuard VPN (`ludus user wireguard --user JM`). Range state: **SUCCESS**.

## Login / GUI page results
| Service | URL | Result |
|---------|-----|--------|
| GrayHats club site | http://10.50.20.10/club/ | ✅ 200 — "Step into the Gray area" |
| WordPress | http://10.50.20.10/wordpress/ | ✅ 200 |
| WordPress login | http://10.50.20.10/wordpress/wp-login.php | ✅ 200 (login form) |
| Wiki.js | http://10.50.10.30:8083/login | ✅ 200 (admin auto-provisioned) |
| Gitea | http://10.50.30.10:3000/user/login | ✅ 200 "Sign In - Gitea" |
| Magento storefront | http://10.50.20.20:8085/ | ✅ 200 "Home page" |
| Magento admin | http://10.50.20.20:8085/admin | ✅ 302 → keyed admin login (normal) |
| Keycloak admin | http://10.50.30.30:8080/admin/ | ✅ 200 "Keycloak Administration Console" |
| MinIO console | http://10.50.30.20:9001/ | ✅ 200 "MinIO Console" |
| waitAPI | http://10.50.30.30:8081/ | ✅ 200 JSON (PRccdc Adventure Park wait times) |
| RideAPI | http://10.50.30.30:8082/ | ✅ 200 JSON (ride catalog) |
| Wazuh | https://10.50.40.10/ | ✅ 200 "Wazuh" |
| Nexus (artifact repo) | http://10.50.30.10:8082/ | ✅ 200 "Sonatype Nexus Repository" |

**All 13 services validated green.**

## AD (prccdc.local) login to web apps — all verified working
| Web app | AD login | How verified |
|---------|----------|--------------|
| **Wiki.js** | ✅ works | GraphQL login as `athompson`/`jkim` → "Login success", JWT issued |
| **Gitea** | ✅ works | API basic-auth as `athompson` → account auto-provisioned (LDAP source `PRCCDC-AD`) |
| **WordPress** | ✅ works | `wp-login.php` POST as `athompson` → 302 to wp-admin, `wordpress_logged_in` cookie set (authLdap) |
| **Keycloak** | ✅ works | realm `ccdc` LDAP federation `ad-ldap`: synced 35 AD users; `athompson`/`jkim` get OIDC tokens from `/realms/ccdc/.../token` |

Two prerequisites were found and fixed in code during validation:
1. **AD accounts had no email** → Wiki.js rejected logins ("Missing or invalid email address"). Fixed
   `ccdc_ad_accounts` to set the `email`/`mail` attribute (`<sam>@prccdc.local`).
2. **WordPress core never loaded** → the `wp-config.php.j2` template used a `{#- ... -#}` Jinja comment
   whose dashes trimmed the newline after `<?php`, producing `<?php/**`; PHP then treated the file as
   plain text and every page 500'd with "undefined function" errors. Fixed the template, plus enabled
   `php_ldap` in php.ini and added a WP-CLI `core install` step (the DB had no WP tables before).
   WordPress local admin: `wpadmin` / `PRccdc-WP-Admin-2026!`.

## Repeatability — full from-scratch rebuild (destroy + redeploy)
Verified by destroying all 11 VMs and redeploying from the config + roles. Result: **repeatable**,
with two findings (both handled), and a clean final state (all 11 services HTTP 200; AD SSH login;
Gitea/WordPress/Keycloak/Wiki.js AD login all working).

1. **Ludus AD/ADWS timing (platform, not our roles):** on first domain creation, Ludus's own
   `Configure default OUs` step can fail with *"Unable to find a default server with Active Directory
   Web Services running"* because ADWS hasn't finished starting after the DC's post-promo reboot.
   It cascades (aborts the role phase for other hosts). **Remedy: run `ludus range deploy` again** —
   the second pass finds AD ready and everything converges. Documented in `scripts/deploy.sh`.
2. **Wiki.js finalize-detection bug (our role, fixed):** Wiki.js creates the `users` table (empty)
   during first-boot migrations, before setup. The role had detected "already finalized" by the
   table's existence, so a fresh deploy skipped `/finalize` and never created the admin (GraphQL 404,
   no AD login). Fixed to detect by admin **row count > 0**. (Only a from-scratch build exposes this —
   the earlier instance had been finalized manually.)

## Defects found during validation and fixed in code
1. **Deploy cascade** — Ludus applies user-roles host-by-host in IP order; one host failing aborts
   the roles phase for all later hosts. The initial Magento failure left `dev01/data01/sso01/wazuh01`
   without Docker. Fixed by correcting the failing roles and redeploying the cut-off hosts (`--limit`).
2. **Magento** — the `alexcheng/magento2` image did not auto-install (served `/setup/`). Added an
   idempotent `bin/magento setup:install` step to `ccdc_magento` (keyed on `app/etc/env.php`).
3. **Gitea crash-loop** — image sshd + Gitea's built-in Go SSH server both bound `:22`. Fixed
   `START_SSH_SERVER=false` in `ccdc_devtools`. Also `gitea admin` CLI must run as `-u git`
   (Gitea refuses to run as root) — fixed.
4. **Wiki.js admin** — was a manual first-run wizard; now auto-provisioned via the `/finalize`
   API in `ccdc_wikijs` (idempotent; skips if already set up).
5. **WordPress club page** — added the static GrayHats-club landing page at `/club/`.
6. **Bitnami images gone** — Bitnami removed Magento/OpenSearch from Docker Hub in 2025; the role
   was rewritten to `alexcheng/magento2:2.2` + `mysql:5.7`.

## Artifact repository: Nexus (default) vs JFrog Artifactory
JFrog Artifactory OSS runs ~6 JVM microservices; on the ballooned 8 GB VM its **router (8082 UI)**
would not stay up sharing RAM with Gitea (the Tomcat service on 8081 did respond). Rather than
dedicate 12 GB to one service, `dev01` now runs **Sonatype Nexus 3** — the equivalent artifact
repository, reliable in ~1.2 GB — validated green at http://10.50.30.10:8082/.

To switch back to JFrog Artifactory: set `ccdc_devtools_artifact_backend: artifactory` in
`ccdc-range.yml` (role_vars for dev01) and raise dev01 to `ram_gb: 12, ram_min_gb: 12`, then
redeploy dev01. The compose template renders either backend from that one variable.

**Nexus admin:** user `admin`, first-boot password from
`docker exec ccdc_nexus cat /nexus-data/admin.password` (Nexus forces a change on first login).

## How to re-validate
```bash
ludus user wireguard --user JM > ccdc-wg.conf && sudo wg-quick up ./ccdc-wg.conf
# then curl each URL above; the range subnet is 10.50.0.0/16
```
