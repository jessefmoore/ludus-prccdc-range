#!/usr/bin/env bash
# =============================================================================
# create-team-user.sh — create a non-admin competition team user and give them
# console-only Proxmox access to the CCDC range (admin only).
#
# Each Ludus user gets a Proxmox account scoped ONLY to their assigned range's
# resource pool. A non-admin user sees just their range's VMs in the Proxmox GUI
# and can open the noVNC console for those VMs — exactly the requirement.
#
# Uses the Ludus v2 CLI (https://docs.ludus.cloud/docs/using-ludus/cli):
# user management moved from `ludus user ...` to `ludus users ...`.
#
# Usage:  ./create-team-user.sh TEAMID "Team Name" RANGEID
#   e.g.  ./create-team-user.sh BLUE1 "PRCCDC Blue Team 1" CCDC
# =============================================================================
set -euo pipefail
TEAMID="${1:?team id (alphanumeric, e.g. BLUE1)}"
NAME="${2:?team display name}"
RANGEID="${3:-CCDC}"

echo "==> Creating non-admin user $TEAMID"
ludus users add --name "$NAME" --userid "$TEAMID"       # NOT --admin  => non-admin

echo "==> Assigning range $RANGEID to $TEAMID (grants scoped Proxmox console access)"
ludus range assign "$TEAMID" "$RANGEID"

cat <<EOF

==> Done.
    - The team logs into Proxmox at https://<proxmox-host>:8006 with the
      Ludus-generated proxmox credentials for user '$TEAMID' (realm: pam).
    - Get those credentials with:  ludus users creds get -u $TEAMID
    - They will see ONLY the '$RANGEID' pool and can open each VM's Console.
    - They are NOT admins: no template building, no other ranges, no shell.
EOF
