# Task A — LAN Connectivity Verification

This document records the results of the machine-to-machine ping tests performed to verify basic network reachability as required by Task A.

## Objective

Verify basic network reachability between the four project machines connected to the private Wi-Fi/LAN, as required by Task A of the project specification.

## Network

| Property | Value |
|---|---|
| Network | 10.7.0.0/19 |
| Gateway | 10.7.0.1 |
| Subnet Mask | 255.255.224.0 |

## Connectivity Matrix

All tests used 4 ICMP echo request packets (`ping -c 4`). The six unique machine-to-machine paths tested are listed below.

| Source | Source IP | Destination | Destination IP | Result | Packet Loss | Avg RTT |
|---|---|---|---|---|---:|---:|
| Mac 1 | 10.7.17.222 | Mac 2 | 10.7.9.11 | PASS | 0% | 42.928 ms |
| Mac 1 | 10.7.17.222 | Mac 3 | 10.7.13.5 | PASS | 0% | 97.689 ms |
| Mac 1 | 10.7.17.222 | Mac 4 | 10.7.11.88 | PASS | 0% | 50.358 ms |
| Mac 2 | 10.7.9.11 | Mac 3 | 10.7.13.5 | PASS | 0% | 55.064 ms |
| Mac 2 | 10.7.9.11 | Mac 4 | 10.7.11.88 | PASS | 0% | 67.174 ms |
| Mac 4 | 10.7.11.88 | Mac 3 | 10.7.13.5 | PASS | 0% | 92.554 ms |

## Detailed Results

### Mac 1 → Mac 2

| Metric | Value |
|---|---|
| Source | 10.7.17.222 |
| Destination | 10.7.9.11 |
| Packets Transmitted | 4 |
| Packets Received | 4 |
| Packet Loss | 0.0% |
| Min RTT | 17.590 ms |
| Avg RTT | 42.928 ms |
| Max RTT | 94.802 ms |
| Stddev | 30.480 ms |

### Mac 1 → Mac 3

| Metric | Value |
|---|---|
| Source | 10.7.17.222 |
| Destination | 10.7.13.5 |
| Packets Transmitted | 4 |
| Packets Received | 4 |
| Packet Loss | 0.0% |
| Min RTT | 40.173 ms |
| Avg RTT | 97.689 ms |
| Max RTT | 162.415 ms |
| Stddev | 44.248 ms |

### Mac 1 → Mac 4

| Metric | Value |
|---|---|
| Source | 10.7.17.222 |
| Destination | 10.7.11.88 |
| Packets Transmitted | 4 |
| Packets Received | 4 |
| Packet Loss | 0.0% |
| Min RTT | 18.383 ms |
| Avg RTT | 50.358 ms |
| Max RTT | 78.469 ms |
| Stddev | 24.711 ms |

### Mac 2 → Mac 3

| Metric | Value |
|---|---|
| Source | 10.7.9.11 |
| Destination | 10.7.13.5 |
| Packets Transmitted | 4 |
| Packets Received | 4 |
| Packet Loss | 0.0% |
| Min RTT | 21.751 ms |
| Avg RTT | 55.064 ms |
| Max RTT | 153.791 ms |
| Stddev | 57.001 ms |

### Mac 2 → Mac 4

| Metric | Value |
|---|---|
| Source | 10.7.9.11 |
| Destination | 10.7.11.88 |
| Packets Transmitted | 4 |
| Packets Received | 4 |
| Packet Loss | 0.0% |
| Min RTT | 15.467 ms |
| Avg RTT | 67.174 ms |
| Max RTT | 143.661 ms |
| Stddev | 49.702 ms |

### Mac 4 → Mac 3

| Metric | Value |
|---|---|
| Source | 10.7.11.88 |
| Destination | 10.7.13.5 |
| Packets Transmitted | 4 |
| Packets Received | 4 |
| Packet Loss | 0.0% |
| Min RTT | 34.719 ms |
| Avg RTT | 92.554 ms |
| Max RTT | 142.169 ms |
| Stddev | 47.717 ms |

## Commands Used

The following command was executed on each source machine for each tested destination:

```bash
ping -c 4 <destination-ip>
```

This uses ICMP echo request/reply (ICMP Type 8 / Type 0) to verify basic Layer 3 reachability between machines on the LAN. Each test sends 4 ICMP packets and reports transmission statistics including packet loss and round-trip time.

## Observations

- **0% packet loss** was observed on all six tested machine-to-machine paths.
- **RTT varies between paths** — average round-trip times ranged from approximately 43 ms to 98 ms across different source-destination pairs.
- Variable RTT alone is not treated as a failure because packet delivery was 100% successful on all tested paths.
- These results confirm that all four machines can communicate over the 10.7.0.0/19 private LAN as required by Task A.

## Conclusion

All six unique machine-to-machine connectivity paths tested for Task A returned 4/4 packets with 0.0% packet loss. The LAN connectivity prerequisite for the project has therefore been verified.
