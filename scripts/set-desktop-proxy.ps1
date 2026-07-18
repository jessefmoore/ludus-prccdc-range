<#
    set-desktop-proxy.ps1
    Point a Windows desktop at the CCDC Squid proxy (CCDC-proxy01 @ 10.50.10.40:3128).
    Run on CCDC-desk01 as the logged-in user (WinINET is per-user) or push via GPO.

    Usage:  powershell -ExecutionPolicy Bypass -File set-desktop-proxy.ps1
            powershell -File set-desktop-proxy.ps1 -Proxy "10.50.10.40:3128"
#>
param(
    [string]$Proxy = "10.50.10.40:3128",
    # Hosts that bypass the proxy (local + AD/domain traffic)
    [string]$Bypass = "10.50.10.*;*.prccdc.local;localhost;127.0.0.1;<local>"
)

$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $key -Name ProxyEnable   -Value 1
Set-ItemProperty -Path $key -Name ProxyServer   -Value $Proxy
Set-ItemProperty -Path $key -Name ProxyOverride -Value $Bypass

# Also set the machine-wide WinHTTP proxy (used by services/updates)
netsh winhttp set proxy proxy-server="$Proxy" bypass-list="$Bypass" | Out-Null

Write-Host "Proxy set to $Proxy (bypass: $Bypass)."
Write-Host "Verify:  (Invoke-WebRequest http://example.com -UseBasicParsing).StatusCode"
Write-Host "Squid access log on the proxy:  tail -f /var/log/squid/access.log"
