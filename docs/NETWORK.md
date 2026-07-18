# CCDC Range — Network & Firewall

## Addressing
`10.50.<vlan>.<octet>` (range 50). The Ludus **router** (Debian, substituting for the requested
Alpine router/firewall) is the gateway/firewall for every VLAN and does NAT to the internet.

| VLAN | Name | Subnet | Hosts |
|------|------|--------|-------|
| 10 | Corporate | 10.50.10.0/24 | dc01 .10, desk01 .20, wiki01 .30, proxy01 .40 |
| 20 | DMZ | 10.50.20.0/24 | web01 .10, shop01 .20 |
| 30 | Internal svc | 10.50.30.0/24 | dev01 .10, data01 .20, sso01 .30 |
| 40 | Security | 10.50.40.0/24 | wazuh01 .10 |

## Current policy (build/lab)
```yaml
network:
  inter_vlan_default: ACCEPT   # everything can talk — needed for AD join + app deps + Wazuh
  external_default:   ACCEPT   # outbound internet for docker/apt/choco/WordPress downloads
  wireguard_vlan_default: ACCEPT
```
Flat by design so the whole stack provisions cleanly. Tighten for competition after a clean baseline snapshot.

## Optional competition hardening (paste into `network:` then redeploy)
Segments the DMZ from the corporate LAN, forces the desktop through Squid, and keeps monitoring open.
```yaml
network:
  inter_vlan_default: REJECT
  external_default: ACCEPT
  rules:
    # Everyone -> DC for auth/DNS (Kerberos, LDAP, DNS, SMB)
    - { name: "AD/DNS to DC", vlan_src: all, vlan_dst: 10, protocol: all, ports: all, action: ACCEPT }
    # Corp desktop -> Squid only for web egress
    - { name: "Desktop to Squid", vlan_src: 10, vlan_dst: 10, protocol: tcp, ports: 3128, action: ACCEPT }
    # Public/other -> DMZ web
    - { name: "Web to DMZ 80/443", vlan_src: all, vlan_dst: 20, protocol: tcp, ports: "80,443,8085", action: ACCEPT }
    # Apps -> internal services (DB, object store, SSO)
    - { name: "Apps to services", vlan_src: 20, vlan_dst: 30, protocol: tcp, ports: "3306,9000,9001,8080", action: ACCEPT }
    # Wazuh agents -> manager
    - { name: "Agents to Wazuh", vlan_src: all, vlan_dst: 40, protocol: tcp, ports: "1514,1515,55000", action: ACCEPT }
```
Adjust to the scenario — this is a starting point, not a graded ruleset.

## Router firewall extensions
Add raw rules via the top-level `router:` key, e.g. a transparent redirect of desktop web to Squid:
```yaml
router:
  iptables_commands:
    - "iptables -t nat -A PREROUTING -s 10.50.10.20 -p tcp --dport 80 -j DNAT --to 10.50.10.40:3128"
```
