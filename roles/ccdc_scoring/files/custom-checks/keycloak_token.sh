#!/bin/sh
# =============================================================================
# keycloak_token.sh — Keycloak OIDC token-issuance check.
# Performs a Resource Owner Password Credentials grant against the given realm
# using the built-in admin-cli client and requires a real access_token in the
# response. This proves Keycloak actually authenticates and mints tokens, which
# a plain "GET /realms/master returns 200" check cannot.
#
# args: <round> <target> <port> <username> <password> <realm>
# USERNAME/PASSWORD arrive shell-escaped from Quotient (positional args here).
# =============================================================================
ROUND="$1"; TARGET="$2"; PORT="$3"; USER="$4"; PASS="$5"; REALM="$6"

resp=$(curl -s --max-time 10 \
  -d "client_id=admin-cli" \
  --data-urlencode "username=${USER}" \
  --data-urlencode "password=${PASS}" \
  -d "grant_type=password" \
  "http://${TARGET}:${PORT}/realms/${REALM}/protocol/openid-connect/token")

if echo "$resp" | jq -e '.access_token | length > 0' >/dev/null 2>&1; then
  echo "SUCCESS: Keycloak realm '${REALM}' issued an access_token for ${USER}"
  exit 0
fi
echo "FAILED: no access_token from ${TARGET}:${PORT} realm '${REALM}': $(echo "$resp" | head -c 200)"
exit 1
