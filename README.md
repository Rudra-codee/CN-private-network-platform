# Computer Networks — Private Network Service Platform

## Project Overview

This repository houses the configuration, documentation, backend services, and protocol verification artifacts for a fully local private network service platform. Built across 4 macOS laptops, this Computer Networks project demonstrates the complete end-to-end network request lifecycle:

**DNS → TCP → TLS → HTTP → Reverse Proxy → Load Balancing**

The underlying application code is intentionally kept simple so that the network architecture, traffic management, protocol mechanics, and system behavior remain the primary focus.

## Phase 1 Progress

### Task A — Establish Private LAN
Status: **COMPLETE** ✅

Verified:
- 4-machine private LAN (10.7.0.0/19)
- IP inventory for all machines
- Subnet/gateway/interface/MAC details recorded
- Machine-to-machine ping connectivity (6 paths, 0% loss)
- Topology documentation

### Task B — Private DNS Server
Status: **COMPLETE** ✅

Verified:
- dnsmasq 2.93 running on Mac 1 (10.7.17.222:53)
- `app.teamX.test` → 10.7.9.11 (Mac 2)
- `api.teamX.test` → 10.7.9.11 (Mac 2)
- Mac 2 and Mac 4 configured as DNS clients
- dig verification evidence collected

### Current Network

| Machine | IPv4 | Role |
|---|---|---|
| Mac 1 | 10.7.17.222 | DNS + Client |
| Mac 2 | 10.7.9.11 | Edge / LB |
| Mac 3 | 10.7.13.5 | Backend A |
| Mac 4 | 10.7.11.88 | Backend B + Client |

### Next Task

**Task C** — Deploy the two HTTP/REST backend services (Backend A on Mac 3, Backend B on Mac 4).

---

## Team Architecture

The physical deployment and role distribution across the four macOS laptops is structured as follows:

- **Mac 1**: Private DNS Server (`dnsmasq`) + Test Client
- **Mac 2**: Edge / Reverse Proxy (`nginx`) + Load Balancer
- **Mac 3**: Backend Service A (HTTP/REST)
- **Mac 4**: Backend Service B (HTTP/REST) + Test Client

## Request Flow

```
Client
  ↓
DNS Query
  ↓
Mac 1 DNS
  ↓
app.teamX.test resolves to Mac 2 IP
  ↓
HTTPS (TCP 443 + TLS)
  ↓
Mac 2 nginx Edge
  ↓
Backend A (Mac 3) / Backend B (Mac 4)
```

## Phase 1 Scope

Phase 1 focuses on building the foundational local network and establishing multi-tier request routing:

- **Private LAN**: Isolated network connection connecting all 4 macOS laptops.
- **Private DNS**: Custom local domain resolution (`app.teamX.test`, `api.teamX.test`).
- **HTTP/REST Backend A**: Lightweight application server running on Mac 3.
- **HTTP/REST Backend B**: Lightweight application server running on Mac 4.
- **nginx Reverse Proxy**: Central edge gateway running on Mac 2 to receive client traffic.
- **Load Balancing**: Round-robin distribution of incoming HTTP requests across Backend A and Backend B.
- **HTTPS / TLS**: Local TLS termination at the nginx edge with trusted certificate configuration.
- **HTTP Caching**: Header-based caching strategies (`Cache-Control`, `304 Not Modified`).
- **Packet Capture and Analysis**: Comprehensive Wireshark verification of DNS, TCP handshake, TLS handshake, and HTTP traffic.
- **Required Failure Demonstrations**: Controlled fault injection testing across DNS, TCP, TLS, and application layers.

## Network Ports

| Service | Protocol | Port | Host Machine | Description |
|---------|----------|------|--------------|-------------|
| DNS | UDP | 53 | Mac 1 | Private domain name resolution |
| HTTPS | TCP | 443 | Mac 2 | Secure client entry point (Edge / Reverse Proxy) |
| Backend A | TCP | 3001 | Mac 3 | Application Server A |
| Backend B | TCP | 3002 | Mac 4 | Application Server B |

## Repository Structure

```
cn-private-network-platform/
├── README.md                 # Main project overview and setup documentation
├── .gitignore                # Git ignore patterns for OS, logs, and environments
├── LICENSE                   # Project license file
├── docs/                     # Project design, architecture, and phase specifications
│   ├── architecture/         # Topology, IP inventory, service maps, and flow diagrams
│   └── phase1/               # Phase 1 requirements, implementation plan, and checklist
├── configs/                  # Service configuration files
│   ├── dns/                  # Private DNS configuration files (dnsmasq)
│   ├── nginx/                # Reverse proxy and load balancer configurations
│   └── tls/                  # Certificate generation scripts and TLS configs
├── backend-a/                # Service A code and configuration instructions
├── backend-b/                # Service B code and configuration instructions
├── scripts/                  # Automated verification and helper utility scripts
├── evidence/                 # Verification artifacts, Wireshark captures, and logs
│   ├── 01-lan/               # Ping outputs and IP configuration evidence
│   ├── 02-dns/               # dig/nslookup verification logs
│   ├── 03-backends/          # Direct backend HTTP request/response logs
│   ├── 04-nginx/             # Reverse proxy and load balancing verification evidence
│   ├── 05-tls/               # Certificate trust and TLS handshake logs
│   ├── 06-caching/           # HTTP Cache-Control and conditional request evidence
│   ├── 07-wireshark/         # .pcap/.pcapng captures and exported packet details
│   └── 08-failures/          # Failure scenario test outputs and trace logs
└── notes/                    # Learning notes, viva preparation, and conceptual Q&A
```
