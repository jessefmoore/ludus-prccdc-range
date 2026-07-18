# ccdc_linux_domain_join

Joins a Debian/Ubuntu VM to the CCDC Active Directory domain **prccdc.local**
using `realmd` + `SSSD` + `adcli`, so AD users can authenticate over SSH and at
the console. Designed to be reliable and idempotent across the CCDC Linux fleet.

## What it does

1. **Preseeds Kerberos** (`debconf` `krb5-config/default_realm = PRCCDC.LOCAL`)
   so the package install never blocks on an interactive prompt.
2. **Installs** `realmd sssd sssd-tools adcli samba-common-bin krb5-user
   packagekit libnss-sss libpam-sss oddjob oddjob-mkhomedir libsss-sudo`.
3. **Fixes DNS first.** The AD domain must resolve before joining. The role
   detects `systemd-resolved`:
   - active  → templates `/etc/systemd/resolved.conf` (DNS = DC, search = domain)
     and restarts resolved immediately.
   - inactive → writes a classic `/etc/resolv.conf`.
   It then verifies the domain with `realm discover` (with retries).
4. **Joins idempotently.** It checks `realm list --name-only`; only if the
   domain is not already joined does it run
   `echo '<pass>' | realm join --user=Administrator [--computer-ou=...] prccdc.local`
   (the join task uses `no_log: true`).
5. **Configures SSSD** via `/etc/sssd/sssd.conf` (mode 0600):
   `use_fully_qualified_names = False`, `fallback_homedir = /home/%u`,
   `default_shell = /bin/bash`, `ad_gpo_access_control = permissive`,
   plus `sudo_provider = ad`.
6. **Enables home-dir creation** on first login (`pam-auth-update --enable
   mkhomedir`, with `oddjobd` running).
7. **Grants sudo** to the AD group `ccdc_sudo_group` via a validated
   `/etc/sudoers.d/ccdc-ad-sudo` drop-in.
8. **Permits logins**: `realm permit --all` (lab default) or, if
   `ccdc_allowed_login_groups` is set, `realm permit --groups <g>` per group.

## Variables (see `defaults/main.yml`)

| Variable | Default | Purpose |
|---|---|---|
| `ccdc_domain` | `prccdc.local` | AD DNS domain (lower case) |
| `ccdc_domain_upper` | `PRCCDC.LOCAL` | Kerberos realm (upper case) |
| `ccdc_domain_netbios` | `PRCCDC` | Short/NetBIOS name |
| `ccdc_dc_ip` | `10.2.10.10` | DC / DNS server IP |
| `ccdc_join_user` | `Administrator` | Privileged AD account for the join |
| `ccdc_join_password` | `PRccdc-Admin-2026!` | Password for join account (override) |
| `ccdc_computer_ou` | `""` | Optional OU DN for the computer object |
| `ccdc_sudo_group` | `domain admins` | AD group granted sudo |
| `ccdc_allowed_login_groups` | `[]` | Groups permitted to log in (empty = all) |

> **Note on `permissive`:** `ad_gpo_access_control = permissive` and
> `realm permit --all` are intentional lab defaults — they keep logins working
> even if GPO/OU access rules are incomplete. Tighten with
> `ccdc_allowed_login_groups` and `enforcing` for a hardened build.

## Verify

```bash
# Host is joined:
realm list                       # shows prccdc.local, "configured: kerberos-member"

# AD identity resolves (no @domain needed thanks to use_fully_qualified_names=False):
id administrator@prccdc.local    # or: id <aduser>
getent passwd <aduser>@prccdc.local

# Login creates a home dir and sudo works for members of the sudo group:
su - <aduser>@prccdc.local
sudo -l
```

## Troubleshooting DNS

- `realm discover prccdc.local` fails → DNS is not pointed at the DC.
  Check `resolvectl status` (systemd-resolved) or `cat /etc/resolv.conf`.
  The nameserver must be `ccdc_dc_ip` and the search domain `prccdc.local`.
- `dig SRV _ldap._tcp.prccdc.local` must return the DC. AD relies on SRV records.
- Kerberos `KRB5KDC_ERR_PREAUTH_FAILED` / clock-skew errors → ensure the VM's
  time is synced to the DC (within 5 minutes); realm/Kerberos are time-sensitive.
- Re-running the role is safe; it will not re-join an already-joined host.
