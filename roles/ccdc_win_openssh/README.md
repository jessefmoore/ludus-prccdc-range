# ccdc_win_openssh

Makes the Windows **OpenSSH server (sshd)** actually reachable on a Windows VM.

The chocolatey `openssh` package (used on `CCDC-desk01`) installs the OpenSSH
binaries but does **not** reliably register the `sshd` service, set it to start
automatically, or open the firewall — so TCP 22 ends up closed even though the
package is "installed". This role fixes all three, idempotently:

1. Registers the `sshd` service if missing (Windows `OpenSSH.Server` capability,
   falling back to the bundled `install-sshd.ps1`).
2. Sets `sshd` (and `ssh-agent`) to **Automatic** start and starts them.
3. Adds an inbound **TCP 22** allow rule to the Windows firewall.

## Vars (`defaults/main.yml`)
| Var | Default | Purpose |
|-----|---------|---------|
| `ccdc_win_openssh_port` | `22` | sshd listen / firewall port |
| `ccdc_win_openssh_firewall_rule_name` | `OpenSSH-Server-In-TCP` | firewall rule name |

## Usage
Add after the desktop's package install (the `openssh` chocolatey package must be
listed on the VM). On `CCDC-desk01`:
```yaml
roles:
  - ccdc_pii
  - ccdc_win_openssh
  - aleemladha.ludus_wazuh_agent
```

## Verify
```
nc -z 10.50.10.20 22          # port open
ssh <aduser>@10.50.10.20 hostname   # -> CCDC-desk01
```
Domain users log in as `PRCCDC\<user>` (SSSD-independent; native Windows OpenSSH
authenticates against AD). Scored by `ccdc_scoring` as `desk01-ssh`.
