# Task A — Network Configuration Evidence

This document records the commands and methodology used to collect network configuration data from each macOS laptop during the Task A LAN setup.

## Commands Used

The following macOS commands were used on each machine to obtain the required network parameters:

### `networksetup -getinfo Wi-Fi`

This command retrieves the current network configuration for the Wi-Fi service, including:

- **IP address** — The IPv4 address assigned to the machine on the Wi-Fi network.
- **Subnet mask** — The subnet mask defining the network segment.
- **Router** — The default gateway address for the network.

```bash
networksetup -getinfo Wi-Fi
```

### `networksetup -listallhardwareports`

This command lists all hardware network ports on the Mac, including:

- **Hardware Port** — The human-readable name of the network service (e.g., Wi-Fi).
- **Device** — The BSD interface name (e.g., `en0`).
- **Ethernet Address** — The MAC address of the network interface.

```bash
networksetup -listallhardwareports
```

## Data Collected

The following information was obtained from each machine:

| Data Point | Source Command |
|---|---|
| IPv4 address | `networksetup -getinfo Wi-Fi` |
| Subnet mask | `networksetup -getinfo Wi-Fi` |
| Router / default gateway | `networksetup -getinfo Wi-Fi` |
| Interface name (e.g., en0) | `networksetup -listallhardwareports` |
| MAC address | `networksetup -listallhardwareports` |

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

- All four machines reported the same subnet mask, default gateway, and active interface.
- All assigned IPv4 addresses fall within the 10.7.0.0/19 address range, confirming membership in the same network segment.
- The Wi-Fi interface (`en0`) is the active network interface on all four machines.
