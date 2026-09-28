# IP & Interface Inventory

This document tracks physical network interfaces, IP addresses, subnets, and MAC addresses for each laptop in the private network cluster.

> [!IMPORTANT]
> Actual IP addresses, MAC addresses, and network interface names must be recorded once the physical LAN is established. Do not populate placeholder values until physical hardware setup is complete.

## Hardware Inventory Table

| Machine | Member | Role | IPv4 | Prefix | Gateway | Interface | MAC |
|---------|--------|------|------|--------|---------|-----------|-----|
| Mac 1 | TBD | DNS + Client | TBD | TBD | TBD | TBD | TBD |
| Mac 2 | TBD | nginx Edge/LB | TBD | TBD | TBD | TBD | TBD |
| Mac 3 | TBD | Backend A | TBD | TBD | TBD | TBD | TBD |
| Mac 4 | TBD | Backend B + Client | TBD | TBD | TBD | TBD | TBD |

## Verification Commands

Run the following commands on each macOS machine to gather interface data:

```bash
# Get active IPv4 address and interface
ifconfig

# Get default gateway
netstat -rn | grep default

# Verify peer connectivity
ping -c 3 <peer-ip>
```
