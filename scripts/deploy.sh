#!/usr/bin/env bash
# =============================================================================
# deploy.sh — push the CCDC range config and deploy it.
# Run on a machine with the `ludus` CLI configured for the deploying user.
#
# Usage:  ./deploy.sh [RANGEID] [TEAMID]
#   RANGEID   defaults to CCDC
#   TEAMID    optional; admins deploy another user's range with --user
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
RANGEID="${1:-CCDC}"
TEAMID="${2:-}"
USER_ARG=""; [[ -n "$TEAMID" ]] && USER_ARG="--user $TEAMID"

echo "==> Setting range config for $RANGEID"
ludus range config set -f ccdc-range.yml $USER_ARG

echo "==> Deploying range $RANGEID (this takes 1-3 hours for all VMs + AD)"
ludus range deploy $USER_ARG

echo "==> Follow progress with:  ludus range logs -f $USER_ARG"
echo "==> Status with:           ludus range list $USER_ARG"

# --- IMPORTANT: fresh AD ranges may need a SECOND deploy pass ----------------
# On a from-scratch build, Ludus's own "Configure default OUs" step (in
# configure-dc.yml, right after domain creation + reboot) can fail with:
#   "Unable to find a default server with Active Directory Web Services running"
# because AD Web Services (ADWS) hasn't finished starting after the DC reboot.
# This is a known Ludus/AD timing transient, NOT a range-role problem, and it
# cascades (aborting the role phase for the other hosts). The fix is simply to
# run the deploy again — by then the DC is fully up and everything converges:
#
#   ludus range deploy $USER_ARG        # re-run once if the first pass ERRORs on the DC
#
# Deploys are idempotent, so re-running is safe and only does remaining work.

# --- Useful partial re-deploys (uncomment as needed) ------------------------
# Re-run only Linux domain joins:
#   ludus range deploy $USER_ARG --only-roles ccdc_linux_domain_join
# Re-run only the app service roles on one host:
#   ludus range deploy $USER_ARG --limit CCDC-dev01
# Re-run only AD account creation:
#   ludus range deploy $USER_ARG --only-roles ccdc_ad_accounts
