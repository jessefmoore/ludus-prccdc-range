#!/usr/bin/env bash
# =============================================================================
# build-templates.sh — build the EXACT OS templates the CCDC spec calls for,
# so you can drop the substitutions in ccdc-range.yml.
#
# The running range uses substitutes (win11 for win10, debian-12 for debian-13,
# ubuntu-22.04 for Rocky) because those templates were already built. The real
# OSes are available from the Bad Sector Labs template source. Building each one
# packs a fresh VM from ISO and can take 30-90 minutes.
#
# After building, edit ccdc-range.yml:
#   win11-22h2-x64-enterprise-template  -> win10-22h2-x64-enterprise-template   (desk01)
#   debian-12-x64-server-template       -> debian-13-x64-server-template        (dev01)
#   ubuntu-22.04-x64-server-template    -> rocky-9-x64-server-template          (shop01/Magento)
# =============================================================================
set -euo pipefail

echo "==> Current templates:"
ludus templates list

echo "==> Ensure the Bad Sector Labs template source is present, then build:"
cat <<'EOF'
  # (Alpine has NO ready Ludus template — the native Debian router IS the firewall.)

  # Windows 10 desktop
  ludus templates build -n win10-22h2-x64-enterprise-template

  # Debian 13 (Gitea/JFrog host)
  ludus templates build -n debian-13-x64-server-template

  # Rocky Linux 9 (Magento host)
  ludus templates build -n rocky-9-x64-server-template

  # Watch progress
  ludus templates logs -f
  ludus templates status
EOF
