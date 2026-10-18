# CCDC Range — Proxmox Access Control (teams range only their VMs' consoles)

## Requirement
Competition users must be able to use the **Proxmox GUI** but only **see and open the console**
of the VMs **in their own range** — nothing else.

## How Ludus satisfies this
Every Ludus user gets a Proxmox account (realm `pam`) whose permissions are scoped to the
**resource pool** of the range(s) assigned to them. A **non-admin** Ludus user:
- logs into the Proxmox web GUI at `https://<proxmox-host>:8006`,
- sees only their assigned range's pool (e.g. the `CCDC` pool),
- can open each VM's **noVNC console**,
- cannot build templates, touch other ranges, or get a host shell.

This is exactly the "range only in the GUI, console only for their VMs" requirement — no manual
Proxmox ACL editing needed.

## What was set up for this range
```
Ludus user : BLUE1  ("PRCCDC Blue Team 1")  — NON-ADMIN
Proxmox login : prccdc-blue-team-1  (realm: pam)   password: PRccdc-Blue1-2026!
Range assigned : CCDC   (rangeNumber 50)
```
Created with `scripts/create-team-user.sh BLUE1 "PRCCDC Blue Team 1" CCDC`
(CLI: `ludus users add --name "PRCCDC Blue Team 1" --userid BLUE1`, then
`ludus range assign BLUE1 CCDC`).

## Add more teams
```bash
scripts/create-team-user.sh BLUE2 "PRCCDC Blue Team 2" CCDC
scripts/create-team-user.sh BLUE3 "PRCCDC Blue Team 3" CCDC
```
For **separate** environments per team, give each its own range (copy `ccdc-range.yml`, deploy under
each team's userID) so teams are fully isolated. Assigning the same `CCDC` range to several users lets
them share one environment (console access for all).

## Retrieve / reset a team's Proxmox credentials
```bash
ludus users creds get -u BLUE1           # show proxmox user/password
ludus users apikey -u BLUE1              # reset Ludus API key
```

## Verify
1. Open an incognito browser → `https://<proxmox-host>:8006`.
2. Log in as `prccdc-blue-team-1` / `PRccdc-Blue1-2026!` (realm **pam**, or Linux PAM).
3. Confirm: only the `CCDC` pool/VMs are visible; Console opens; other ranges are absent.
