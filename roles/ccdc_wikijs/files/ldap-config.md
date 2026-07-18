# Wiki.js - Active Directory (LDAP) authentication: ready-to-paste settings

This is the exact configuration to enable **Active Directory / LDAP** login for
domain **prccdc.local** in the Wiki.js admin UI. Values below are the role
defaults (see `defaults/main.yml`); substitute any you overrode via Ludus
`role_vars`.

Wiki.js stores auth strategies in its database, populated through the admin UI.
There is no supported environment-variable path for LDAP in the stable 2.x
image, so this is configured **once** in the browser after the first-run wizard.
(The role also attempts a best-effort DB seed of exactly these settings — see
the project README — but the UI is the source of truth.)

## Where to enter it

1. Log in as the local admin.
2. Go to **Administration → Authentication**.
3. Click **+ Add Strategy** and choose **LDAP / Active Directory**.
4. Fill in the fields below, click **Apply**, then **Save**.

## Strategy fields

| Field | Value |
| --- | --- |
| **Display Name** | `Active Directory` |
| **LDAP URL** | `ldap://10.2.10.10:389`  *(use `ldaps://10.2.10.10:636` for TLS — see below)* |
| **Admin Bind DN** | `cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local` |
| **Admin Bind Credentials** | `PRccdc-Svc-2026!` |
| **Search Base** | `ou=CCDC,dc=prccdc,dc=local` |
| **Search Filter** | `(&(objectClass=user)(sAMAccountName={{username}}))` |
| **Use TLS** | *off* (389) — turn **on** only for LDAPS/636 |
| **Verify TLS Certificate** | off (lab; DC uses a self-signed/AD-CA cert) |
| **Unique ID Field Mapping** | `objectGUID`  *(or `sAMAccountName`)* |
| **Email Field Mapping** | `mail` |
| **Display Name Field Mapping** | `displayName`  *(falls back to `cn`)* |
| **Avatar Picture Field Mapping** | *(leave blank)* |
| **Allow self-registration** | **on** (auto-creates the wiki account on first AD login) |
| **Assign to group** | *(optional)* pick a Wiki.js group to auto-enroll AD users into |

> **Search filter token:** Wiki.js / `passport-ldapauth` replaces the
> `{{username}}` token with the login name. Some documentation refers to this
> placeholder as `{{input}}`; the value Wiki.js actually parses is
> `{{username}}`, so use the filter exactly as written above.

## Search base options

- `ou=CCDC,dc=prccdc,dc=local` — the CCDC OU layout (service + employee users).
- `cn=Users,dc=prccdc,dc=local` — the default Users container.
- `dc=prccdc,dc=local` — the whole domain (widest; needed if users live in
  multiple containers). The bind account must be able to read that subtree.

## TLS / LDAPS variant (port 636)

If you want encrypted LDAP:

| Field | Value |
| --- | --- |
| **LDAP URL** | `ldaps://10.2.10.10:636` |
| **Use TLS** | **on** |
| **Verify TLS Certificate** | off in the lab (the DC's cert is self-signed / issued by the AD CA), or on if you import the CA |

Everything else (bind DN, search base, filter, mappings) is unchanged.

## After saving

- Log out. The Wiki.js login page now shows an **Active Directory** button/option.
- Sign in with a domain account, e.g. `athompson` / that user's AD password
  (sAMAccountName, not the UPN).
- With self-registration on, the Wiki.js account is created automatically on
  first successful login.

## Verifying the bind account from the wiki VM

```bash
# Requires ldap-utils (apt-get install -y ldap-utils) if you want to test the
# bind independently of Wiki.js:
ldapsearch -x -H ldap://10.2.10.10:389 \
  -D "cn=svc_ldap,ou=ServiceAccounts,ou=CCDC,dc=prccdc,dc=local" \
  -w 'PRccdc-Svc-2026!' \
  -b "ou=CCDC,dc=prccdc,dc=local" \
  "(&(objectClass=user)(sAMAccountName=athompson))" dn mail displayName
```

A returned entry confirms the bind DN, password, search base, and filter are
all correct — paste the same values into Wiki.js.
