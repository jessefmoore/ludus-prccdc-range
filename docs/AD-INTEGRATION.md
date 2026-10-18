# CCDC Range — Active Directory Integration

Domain **prccdc.local** (NetBIOS `PRCCDC`), DC `CCDC-dc01` @ `10.50.10.10` (also DNS for all VMs).

## 1. Windows domain members
`CCDC-desk01` and `CCDC-web01` join via the Ludus `domain: { role: member }` key. `CCDC-dc01`
is `role: primary-dc`. Ludus handles promotion, DNS, and join automatically.

## 2. Linux domain join (all Linux VMs)
Role **`ccdc_linux_domain_join`** (realmd + SSSD + adcli) runs on wiki01, proxy01, shop01, dev01,
data01, sso01, wazuh01. It:
- points DNS at the DC (`primary_dns_server: 10.50.10.10` + managed resolv/`resolved.conf`),
- `realm join`s `prccdc.local` with `Administrator` (idempotent — checks `realm list` first),
- writes `sssd.conf` (`use_fully_qualified_names=False`, `fallback_homedir=/home/%u`),
- enables `mkhomedir`, and grants **sudo to `domain admins`**.

Verify on any Linux VM:
```bash
realm list                       # shows prccdc.local, "configured: kerberos-member"
id athompson@prccdc.local        # resolves an AD user
su - athompson                   # login creates /home/athompson
```

## 3. Service accounts (role `ccdc_ad_accounts`, runs on the DC)
Creates `OU=CCDC` → `ServiceAccounts`, `Employees`, `Groups`; the `svc_*` service accounts
(group `CCDC-WebApps`) and ~10 employee users (group `CCDC-Employees`). Web apps/DBs bind or
authenticate using these accounts. Default service pw `PRccdc-Svc-2026!`, employee pw `PRccdc-User-2026!`.

## 4. Web-app AD/LDAP login
All bind with **`svc_ldap`** (`cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local`).

| App | Mechanism | Status |
|-----|-----------|--------|
| **Wiki.js** | LDAP/AD strategy (in-app) | deployed; enable in Admin→Auth using `roles/ccdc_wikijs/files/ldap-config.md` (best-effort DB seed included) |
| **WordPress** | authLdap plugin, pre-seeded via mu-plugin | automated; AD users auto-provision at `/wordpress/wp-login.php` |
| **Gitea** | native LDAP (BindDN) auth source `PRCCDC-AD` | automated via `gitea admin auth add-ldap` |
| **Keycloak** | LDAP user federation → AD | ✅ wired by `ccdc_sso` (realm `ccdc`, provider `ad-ldap`); AD users sync + authenticate |
| **Magento** | LDAP module or Keycloak SSO front | best-effort/manual (see `roles/ccdc_magento/README.md`) |

Common LDAP settings:
```
Host/URI : ldap://10.50.10.10:389        (636 for LDAPS)
Base DN  : dc=prccdc,dc=local
Bind DN  : cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local
Bind PW  : PRccdc-Svc-2026!
User filter : (&(objectClass=user)(sAMAccountName=%s))     # token varies per app
Attrs    : sAMAccountName / displayName / mail / memberOf
```

## 5. Ordering note
Within a single deploy, AD account creation and the LDAP-consuming roles may run close together.
If an app's AD login isn't working right after the first deploy, re-run:
```bash
ludus range deploy -r CCDC -u JM --only-roles ccdc_ad_accounts
ludus range deploy -r CCDC -u JM --only-roles ccdc_wikijs,ccdc_devtools,ccdc_wordpress
```
