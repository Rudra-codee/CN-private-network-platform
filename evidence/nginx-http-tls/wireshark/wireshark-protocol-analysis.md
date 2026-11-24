# Wireshark Packet Capture & Protocol Flow Evidence

**Component:** Packet Capture & Multi-Layer Protocol Flow Analysis (Task G)  
**Capture Node:** Mac 1 Client (`10.7.26.214`)  
**Target Server:** Mac 2 Edge Proxy (`10.7.26.200:8443`)  
**Auditor:** Kaustubh Hiwanj (Senior Computer Networks Engineer)  
**Status:** **VERIFIED FROM ARTIFACTS**

---

## 1. Overview & Capture Artifact Inventory

Network packet traces were captured using Wireshark on Mac 1 to demonstrate the complete, end-to-end request lifecycle:
```
DNS Resolution (Port 53) ──► TCP 3-Way Handshake ──► TLS 1.3 Handshake ──► Encrypted HTTP Exchange
```

The captured artifacts are archived in [`evidence/07-wireshark/mac1/`](../../07-wireshark/mac1/):

| Artifact Filename | Artifact Link | Protocol Scope | Capture Location |
|---|---|---|---|
| `mac1-tls13-https-capture.png` | [`mac1-tls13-https-capture.png`](../../07-wireshark/mac1/mac1-tls13-https-capture.png) | TLS 1.3 Handshake & Application Data | Mac 1 (`en0`) |
| `mac1-backend-a-response.png` | [`mac1-backend-a-response.png`](../../07-wireshark/mac1/mac1-backend-a-response.png) | HTTP Response & Caching Headers | Mac 1 Terminal |
| `mac1-private-dns-verification.png`| [`mac1-private-dns-verification.png`](../../07-wireshark/mac1/mac1-private-dns-verification.png) | Authoritative DNS Query & Response | Mac 1 Terminal |
| `README.md` | [`README.md`](../../07-wireshark/mac1/README.md) | Task G Comprehensive Protocol Analysis | Mac 1 |

---

## 2. Capture Artifact Breakdown & Inspection

### 2.1 Artifact 1: TLS 1.3 & HTTPS Wireshark Trace (`mac1-tls13-https-capture.png`)

- **Capture Filter**: `tls && ip.addr == 10.7.26.200 && tcp.port == 8443`
- **Source Endpoint**: Mac 1 (`10.7.26.214`), Ephemeral Ports (`63353`, `63316`)
- **Destination Endpoint**: Mac 2 (`10.7.26.200:8443`)
- **Key Frame Inspection (`Frame 50240`)**:
  - **Ethernet II**: Source `ba:a7:57:c8:d2:49` $\rightarrow$ Destination `56:76:4c:c8:d5:77`
  - **IPv4 Layer**: Source `10.7.26.214` $\rightarrow$ Destination `10.7.26.200`
  - **TCP Layer**: Source Port `63353` $\rightarrow$ Destination Port `8443`, Seq `503`, Ack `2699`, Len `24`
  - **TLS Layer**: Encrypted `Application Data`
- **Protocol Flow Demonstrated**:
  1. **ClientHello**: Sent with TLS 1.3 protocol declaration, supported cipher suites, and `SNI: app.teamx.test` (length 390 bytes).
  2. **ServerHello & ChangeCipherSpec**: Returned by Mac 2 on port 8443, confirming cipher `TLS_CHACHA20_POLY1305_SHA256` (length 1514 bytes).
  3. **Application Data**: Sockets transition to symmetric encrypted transport.

---

### 2.2 Artifact 2: Application Response & Caching (`mac1-backend-a-response.png`)

- **Command**: `curl -i https://app.teamX.test:8443/api/status`
- **Demonstrated Fields**:
  - `HTTP/1.1 200 OK`
  - `Server: nginx/1.31.6`
  - `X-Backend: A`
  - `ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"`
  - `Cache-Control: public, max-age=60`
  - `X-Cache-Status: MISS` (Initial) and `X-Cache-Status: HIT` (Immediate retry)
- **Protocol Flow Demonstrated**:
  - Validates that decrypted TLS application data at Nginx is proxied upstream, receives origin headers, and enforces client caching.

---

### 2.3 Artifact 3: Authoritative DNS Resolution (`mac1-private-dns-verification.png`)

- **Command**: `dig @10.7.26.214 app.teamX.test`
- **Demonstrated Fields**:
  - `status: NOERROR`
  - `flags: qr aa rd ra` (`aa` flag confirms authoritative answer from `dnsmasq`)
  - `app.teamX.test. 0 IN A 10.7.26.200`
  - `SERVER: 10.7.26.214#53`
- **Protocol Flow Demonstrated**:
  - Proves that before TCP/TLS handshakes begin, client name resolution translates `app.teamX.test` to the edge IP.

---

## 3. Wireshark Limitations & Missing Raw Artifacts

> [!WARNING]
> **Audit Finding — Raw Trace File Availability:**  
> - **Screenshots Present**: High-resolution PNG captures showing filtered frames and terminal verification exist in `evidence/07-wireshark/mac1/`.
> - **Missing Raw PCAP Files**: The underlying binary `.pcap` or `.pcapng` capture files were not committed to the repository (likely omitted due to binary file size constraints or `.gitignore`).
> - **Capture Vantage Point**: Captures were executed from the client machine (Mac 1). No server-side capture from Mac 2's interface was recorded.
> - **Classification**: **VERIFIED FROM ARTIFACTS / RAW PCAP MISSING**.
