# ccdc_ad_accounts

Provisions the Active Directory object layout for the PRCCDC range on the
**primary Domain Controller** (Windows Server, domain `prccdc.local`,
base DN `dc=prccdc,dc=local`). Idempotent — safe to re-run.

Uses the `microsoft.ad` collection for OUs, users, and groups.

## What it creates

### OU structure (under `dc=prccdc,dc=local`)
```
OU=CCDC
  OU=ServiceAccounts   # service accounts
  OU=Employees         # employee / competition users
  OU=Groups            # security groups
```

### Service accounts (`OU=ServiceAccounts,OU=CCDC,...`)
Created enabled, password never expires, user cannot change password:

| sAMAccountName | Purpose |
| -------------- | ------------------------------------------- |
| svc_wiki       | Wiki.js app service account                 |
| svc_wordpress  | WordPress                                   |
| svc_magento    | Magento                                     |
| svc_gitea      | Gitea                                       |
| svc_mysql      | MySQL                                       |
| svc_minio      | MinIO                                       |
| svc_keycloak   | Keycloak                                    |
| svc_wazuh      | Wazuh                                       |
| svc_ldap       | **LDAP bind account used by Wiki.js** — a normal enabled user that can read the directory |

All service accounts are members of the security group **CCDC-WebApps**
(in `OU=Groups`).

### Employee users (`OU=Employees,OU=CCDC,...`)
~10 realistic sample staff accounts (Alice Thompson / `athompson`, etc.),
enabled, all members of the security group **CCDC-Employees**. These represent
staff whose accounts can log into the Wiki and other apps.

## Default passwords

| Variable | Default | Applies to |
| -------- | ------- | ---------- |
| `ccdc_ad_accounts_default_password`  | `PRccdc-Svc-2026!`  | any service account not given an explicit password |
| `ccdc_ad_accounts_employee_password` | `PRccdc-User-2026!` | all employee users |

Per-service passwords can be set individually via the
`ccdc_ad_accounts_service_passwords` map. **Override these defaults for any real
deployment.** All password vars are overridable through Ludus `role_vars`.

## Key variables

See `defaults/main.yml` for the full list. Highlights:

- `ccdc_ad_accounts_domain_base_dn` (default `dc=prccdc,dc=local`)
- `ccdc_ad_accounts_service_accounts` — list of service-account SAMs
- `ccdc_ad_accounts_service_passwords` — per-account password map
- `ccdc_ad_accounts_employees` — list of `{ name, sam, password? }` dicts
- `ccdc_ad_accounts_webapps_group_name` (default `CCDC-WebApps`)
- `ccdc_ad_accounts_employees_group_name` (default `CCDC-Employees`)

Example Ludus `role_vars` override:
```yaml
- vm_name: dc01
  roles:
    - ccdc_ad_accounts
  role_vars:
    ccdc_ad_accounts_default_password: "S3cret-Svc!"
    ccdc_ad_accounts_employee_password: "S3cret-User!"
    ccdc_ad_accounts_service_passwords:
      svc_ldap: "Bind-Only-Reader-99!"
```

## Verify (run on the DC)

```powershell
# All users created by this role
Get-ADUser -Filter * -SearchBase "OU=CCDC,DC=prccdc,DC=local" |
  Select-Object Name, SamAccountName, Enabled | Format-Table

# Just service accounts
Get-ADUser -Filter * -SearchBase "OU=ServiceAccounts,OU=CCDC,DC=prccdc,DC=local"

# Group membership
Get-ADGroupMember -Identity CCDC-WebApps  | Select-Object SamAccountName
Get-ADGroupMember -Identity CCDC-Employees | Select-Object SamAccountName

# OU structure
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=CCDC,DC=prccdc,DC=local"
```

`svc_ldap` should show `Enabled = True` and be usable as a Wiki.js LDAP bind DN:
`CN=svc_ldap,OU=ServiceAccounts,OU=CCDC,DC=prccdc,DC=local`.
