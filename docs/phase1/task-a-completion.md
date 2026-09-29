# Task A — Completion Report

## Objective

Establish and verify the common private LAN required by the project. All four macOS laptops must be connected to the same private Wi-Fi/LAN, with network parameters recorded and basic reachability confirmed.

## Requirements

| Requirement | Status |
|---|---|
| All four Macs connected to same private LAN | ✅ Verified by matching network configuration |
| IPv4 address recorded for each Mac | ✅ |
| Subnet/prefix recorded for each Mac | ✅ |
| Default gateway recorded for each Mac | ✅ |
| Active interface name recorded for each Mac | ✅ |
| MAC address recorded for each Mac | ✅ |
| Pairwise machine reachability tested (ping) | ✅ |
| Topology diagram documented | ✅ |

## Final Network

| Property | Value |
|---|---|
| Network | 10.7.0.0/19 |
| Subnet Mask | 255.255.224.0 |
| Gateway | 10.7.0.1 |
| Interface | en0 (all machines) |

## Machine Summary

| Machine | Role | IPv4 |
|---|---|---|
| Mac 1 | Private DNS + Client | 10.7.17.222 |
| Mac 2 | Edge / Reverse Proxy + Load Balancer | 10.7.9.11 |
| Mac 3 | Backend Server A | 10.7.13.5 |
| Mac 4 | Backend Server B + Client | 10.7.11.88 |

## Connectivity Verification

Six unique machine-to-machine paths were tested using `ping -c 4`. All returned 4/4 packets with 0.0% packet loss.

| Path | Avg RTT |
|---|---|
| Mac 1 → Mac 2 | 42.928 ms |
| Mac 1 → Mac 3 | 97.689 ms |
| Mac 1 → Mac 4 | 50.358 ms |
| Mac 2 → Mac 3 | 55.064 ms |
| Mac 2 → Mac 4 | 67.174 ms |
| Mac 4 → Mac 3 | 92.554 ms |

## Result

Task A has been completed and documented. The private LAN foundation is established, and all four machines are verified as reachable.

## Boundary

Task A verifies the LAN foundation only. The following are **NOT** yet implemented:

- Private DNS (dnsmasq)
- Backend applications
- nginx reverse proxy
- Load balancing
- HTTPS / TLS
- HTTP caching
- Wireshark protocol evidence
- Failure scenario demonstrations

These items are addressed in subsequent Phase 1 tasks (Tasks B through H).
