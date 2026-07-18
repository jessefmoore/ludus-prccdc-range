# CCDC Custom Ludus Role Conventions (READ BEFORE AUTHORING)

These roles are applied by Ludus to VMs after deploy. Follow these rules exactly so the
roles install cleanly via `ludus ansible role add -d <dir>` and run under Ludus's ansible.

## Layout (every role)
```
<rolename>/
  meta/main.yml          # galaxy_info with role_name + namespace 'ccdc', min_ansible_version 2.12
  defaults/main.yml      # all tunables, namespaced with the role name prefix
  tasks/main.yml         # idempotent tasks, fully-qualified module names
  templates/*.j2         # jinja templates (docker-compose.yml.j2, configs)
  files/*                # static files
  handlers/main.yml      # if needed
  README.md              # what it does, ports, vars
```

## Hard rules
- Use FULLY-QUALIFIED module names only: `ansible.builtin.*`, `ansible.posix.*`, `community.general.*`,
  `ansible.windows.*`, `community.windows.*`, `microsoft.ad.*`. These collections ARE installed.
- Do NOT use `community.docker.*` (collection NOT installed). For containers: write a compose file with
  `ansible.builtin.template`, then run `ansible.builtin.command: docker compose up -d` (chdir to the stack dir),
  guarded with `changed_when`/`creates` where sensible. Assume Docker + the `docker compose` plugin are ALREADY
  installed (the VM lists `geerlingguy.docker` before this role). Do not install Docker yourself.
- Idempotent: safe to re-run. Use `creates:`, `state:` args, and check-before-change.
- Namespace ALL variables in defaults/main.yml with the role name (e.g. `ccdc_wordpress_db_password`) because
  Ludus passes role_vars to ALL roles on a VM (avoid collisions).
- Never hardcode range-specific IPs; accept them as vars with sensible defaults.
- meta/main.yml `galaxy_info.role_name` MUST equal the directory name; `namespace: ccdc`.
- Linux stack dirs live under `/opt/ccdc/<service>/`. Create with mode 0755.
- Keep it reliable over clever. Prefer official upstream Docker images. Pin to a major tag (e.g. `:2`, `:latest` ok for lab).
- Add a short README.md documenting exposed ports, credentials/vars, and how to verify the service.

## AD / domain context (for roles that integrate with AD)
- Domain: `prccdc.local`  (NetBIOS `PRCCDC`)
- DC IP: `10.{{ ccdc_second_octet | default('2') }}.10.10` — but prefer using the DNS/domain name.
- Domain admin: `Administrator` / password provided via var.
- LDAP base DN: `dc=prccdc,dc=local`. Users container: `cn=Users,dc=prccdc,dc=local`.
- Service accounts are created on the DC by the `ccdc_ad_accounts` role; other roles just consume creds via vars.

## Verification
Each role's README must include a one-line check (e.g. `curl -I http://localhost:PORT`).
