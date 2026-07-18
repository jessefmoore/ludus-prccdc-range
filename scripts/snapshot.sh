#!/usr/bin/env bash
# =============================================================================
# snapshot.sh — snapshot / rollback the whole CCDC range (competition resets).
# Take a clean snapshot after a good deploy, then roll back between rounds.
#
# Usage:
#   ./snapshot.sh take   [NAME]     # default name: clean-baseline
#   ./snapshot.sh list
#   ./snapshot.sh revert [NAME]
# =============================================================================
set -euo pipefail
ACTION="${1:?take|list|revert}"
NAME="${2:-clean-baseline}"

case "$ACTION" in
  take)   ludus snapshot create --name "$NAME" --description "CCDC baseline" ;;
  list)   ludus snapshot list ;;
  revert) ludus snapshot rollback --name "$NAME" ;;
  *) echo "unknown action: $ACTION"; exit 1 ;;
esac
