# IP and Machine Inventory

This document records the physical network interfaces, IP addresses, subnets, and MAC addresses for each laptop in the private network cluster. Values were collected from macOS network configuration commands after connecting all four machines to the common private LAN.

## Network Configuration

| Property | Value |
|---|---|
| Network | 10.7.0.0/19 |
| Subnet Mask | 255.255.224.0 |
| Default Gateway | 10.7.0.1 |
| Network Type | Private Wi-Fi/LAN |
| Active Interface | en0 |

## Machine Inventory

| Machine | Role | IPv4 | Prefix | Subnet Mask | Gateway | Interface | Wi-Fi MAC |
|---|---|---|---|---|---|---|---|
| Mac 1 | Private DNS + Client | 10.7.17.222 | /19 | 255.255.224.0 | 10.7.0.1 | en0 | 10:9f:41:e0:eb:7b |
| Mac 2 | Edge / Reverse Proxy + Load Balancer | 10.7.9.11 | /19 | 255.255.224.0 | 10.7.0.1 | en0 | 10:9f:41:bc:df:7a |
| Mac 3 | Backend Server A | 10.7.13.5 | /19 | 255.255.224.0 | 10.7.0.1 | en0 | 10:9f:41:bd:d1:6e |
| Mac 4 | Backend Server B + Client | 10.7.11.88 | /19 | 255.255.224.0 | 10.7.0.1 | en0 | 10:9f:41:c0:4e:8d |

## Notes

- All four machines use the same subnet mask (255.255.224.0 or /19).
- All four machines use the same default gateway (10.7.0.1).
- All assigned addresses belong to the 10.7.0.0/19 private network range.
- The active Wi-Fi interface is `en0` on each Mac.
- These values were collected from macOS network configuration commands (`networksetup -getinfo Wi-Fi`, `networksetup -listallhardwareports`).

## Verification Commands

The following commands were used on each macOS machine to gather interface data:

```bash
# Get IPv4 address, subnet mask, and gateway
networksetup -getinfo Wi-Fi

# Get interface name and MAC address
networksetup -listallhardwareports
```
