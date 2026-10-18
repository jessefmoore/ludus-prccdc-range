#!/usr/bin/env bash
# =============================================================================
# snapshot.sh — snapshot / revert the CCDC range (competition resets).
# Take a clean snapshot after a good deploy, then revert between rounds.
#
# Ludus v2 CLI (https://docs.ludus.cloud/docs/using-ludus/cli): snapshot
# management moved from `ludus snapshot ...` to `ludus snapshots ...` and is
# scoped to a range (-r/--range) rather than a named snapshot. By default all
# VMs in the range are snapshotted/reverted; pass -n/--vmids to limit to
# specific VMs. Run `ludus snapshots --help` to confirm flags on your version.
#
# Usage:
#   ./snapshot.sh take   [RANGEID] [DESCRIPTION]   # default range: CCDC
#   ./snapshot.sh list   [RANGEID]
#   ./snapshot.sh revert [RANGEID]
# =============================================================================
set -euo pipefail
ACTION="${1:?take|list|revert}"
RANGEID="${2:-CCDC}"
DESC="${3:-CCDC baseline}"

case "$ACTION" in
  take)   ludus snapshots create -r "$RANGEID" -d "$DESC" ;;
  list)   ludus snapshots list   -r "$RANGEID" ;;
  revert) ludus snapshots revert -r "$RANGEID" ;;
  *) echo "unknown action: $ACTION"; exit 1 ;;
esac
