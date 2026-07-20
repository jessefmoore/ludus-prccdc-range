#!/bin/sh
# =============================================================================
# squid_proxy.sh — functional Squid forward-proxy check.
# Fetches a URL THROUGH the proxy and requires HTTP 200. This proves the proxy
# actually forwards traffic, which a bare TCP port check cannot. Runs from the
# in-range Quotient runner, whose source IP is inside Squid's allowed CIDR.
#
# args: <round> <proxy_ip> <proxy_port> <url>
# Prints SUCCESS/FAILED (paired with Regex="SUCCESS" in event.conf) and exits
# 0 on success, non-zero on failure.
# =============================================================================
ROUND="$1"; PROXY="$2"; PORT="$3"; URL="$4"

code=$(curl -s -x "http://${PROXY}:${PORT}" --max-time 10 -o /dev/null -w "%{http_code}" "$URL")
if [ "$code" = "200" ]; then
  echo "SUCCESS: fetched ${URL} through proxy ${PROXY}:${PORT} (HTTP 200)"
  exit 0
fi
echo "FAILED: proxy ${PROXY}:${PORT} returned HTTP ${code} for ${URL}"
exit 1
