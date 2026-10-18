#!/usr/bin/env bash
# =============================================================================
# install-roles.sh — install every role the CCDC range needs into Ludus.
# Run on a machine with the `ludus` CLI configured for the deploying user
# (Ludus v2 CLI — https://docs.ludus.cloud/docs/using-ludus/cli).
# Idempotent: re-running just re-adds/updates the roles.
#
# Usage:  ./install-roles.sh [--user TEAMID]
#   --user TEAMID   install into another user's scope (admin only, -u/--user)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."          # repo root
ROLES_DIR="roles"
USER_ARG=""
[[ "${1:-}" == "--user" ]] && USER_ARG="-u ${2:?user id required}"

echo "==> Installing community roles from Ansible Galaxy"
# Wazuh SIEM (manager + agents)
ludus ansible role add aleemladha.wazuh_server_install $USER_ARG || true
ludus ansible role add aleemladha.ludus_wazuh_agent   $USER_ARG || true
# Docker (used by every Linux service host)
ludus ansible role add geerlingguy.docker             $USER_ARG || true

echo "==> Installing custom CCDC roles from local directories"
for role in \
    ludus_squid \
    ccdc_ad_accounts \
    ccdc_pii \
    ccdc_linux_domain_join \
    ccdc_wordpress \
    ccdc_magento \
    ccdc_devtools \
    ccdc_data \
    ccdc_sso \
    ccdc_wikijs \
    ccdc_proxy_gpo \
    ccdc_win_openssh \
    ccdc_scoring ; do
  echo "    - $role"
  ludus ansible role add -d "${ROLES_DIR}/${role}" $USER_ARG --force
done

echo "==> Done. Verify with:  ludus ansible role list $USER_ARG"
