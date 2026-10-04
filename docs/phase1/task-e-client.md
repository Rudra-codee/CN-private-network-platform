# Task E — HTTPS / TLS Client Configuration (Mac 1)

**Task:** E — HTTPS / TLS  
**Machine:** Mac 1 (10.7.17.222)  
**Scope:** Client-side only (DNS configuration, CA trust, HTTPS verification)  
**Date:** 2026-09-30

---

## Overview

Task E adds TLS encryption between clients and nginx. Mac 2 runs the HTTPS server (nginx with mkcert certificates on port 8443). Mac 1's role is:

1. Configure system DNS to use its own dnsmasq server
2. Install and trust the CA certificate from Mac 2
3. Verify HTTPS connectivity without bypassing certificate validation

### Architecture

```
Mac 1 (Client)                     Mac 2 (nginx)              Backends
─────────────────                  ───────────────             ──────────
                     HTTPS/TLS
curl/browser  ──────────────────►  nginx:8443     ──── HTTP ──► Backend A (10.7.13.5:3001)
                  TLSv1.3                                  └──► Backend B (10.7.29.244:3002)
                  port 8443            │
                                       └── TLS termination
                                           (mkcert certificate)
```

> **Important:** TLS terminates at nginx. The connection between nginx and backends is plain HTTP. The backends do NOT run HTTPS.

---

## 1. DNS Configuration

### Setting System DNS

Mac 1 must resolve `app.teamX.test` through its own dnsmasq server, not through a public DNS.

```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.17.222
```

### Verification

```bash
$ networksetup -getdnsservers Wi-Fi
10.7.17.222
```

### DNS Resolution (System DNS — no `@` override)

```bash
$ dig app.teamX.test
;; ANSWER SECTION:
app.teamX.test.     0   IN  A   10.7.9.11
;; SERVER: 10.7.17.222#53(10.7.17.222)

$ dig api.teamX.test
;; ANSWER SECTION:
api.teamX.test.     0   IN  A   10.7.9.11
;; SERVER: 10.7.17.222#53(10.7.17.222)
```

### Internet DNS Forwarding

```bash
$ dig google.com
;; ANSWER SECTION:
google.com.     297 IN  A   192.178.158.139
...
;; SERVER: 10.7.17.222#53(10.7.17.222)
```

dnsmasq correctly forwards non-project domains to upstream DNS.

---

## 2. CA Certificate Installation

### Prerequisites

- Mac 2 generated the CA using `mkcert`
- Only `rootCA.pem` (public cert) was transferred to Mac 1
- `rootCA-key.pem` (private key) was **NOT** transferred

### Installation

```bash
sudo security add-trusted-cert \
  -d \
  -r trustRoot \
  -k /Library/Keychains/System.keychain \
  ~/Downloads/rootCA.pem
```

### Trust Verification

```bash
$ security find-certificate -a -c "mkcert" /Library/Keychains/System.keychain
keychain: "/Library/Keychains/System.keychain"
    "alis"<blob>="mkcert kaustubhhiwanj@kaustubhs-macbook-pro-2.local (kaustubh hiwanj)"
```

**CA is present in the System keychain and trusted.**

---

## 3. HTTPS Verification

### Basic HTTPS Request (No `-k`)

```bash
$ curl -i https://app.teamX.test:8443/api/status
HTTP/1.1 200 OK
Server: nginx/1.31.6
Content-Type: application/json; charset=utf-8
X-Backend: A
{"backend":"A","status":"ok"}
```

No `-k` / `--insecure` flag used. Certificate validates automatically against the trusted CA.

### Verbose TLS Output

```bash
$ curl -v https://app.teamX.test:8443/api/status
* Connected to app.teamX.test (10.7.9.11) port 8443
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* Server certificate:
*  subject: O=mkcert development certificate
*  subjectAltName: host "app.teamX.test" matched cert's "app.teamX.test"
*  issuer: O=mkcert development CA; CN=mkcert kaustubhhiwanj@...
*  SSL certificate verify ok.
```

### TLS Handshake Explanation

| Step | Message | Description |
|------|---------|-------------|
| 1 | **ClientHello** | Client sends supported TLS versions and cipher suites |
| 2 | **ServerHello** | Server selects TLSv1.3 with CHACHA20-POLY1305-SHA256 |
| 3 | **Certificate** | Server presents mkcert-signed certificate |
| 4 | **CERT verify** | Client verifies cert chain against trusted CA |
| 5 | **Key Exchange** | Ephemeral key exchange (implicit in TLSv1.3) |
| 6 | **Finished** | Both sides confirm handshake integrity |
| 7 | **Application data** | Encrypted HTTP request/response begins |

---

## 4. HTTPS Load Balancing

```bash
$ for i in {1..10}; do
    echo "Request $i"
    curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null \
      | grep -i "X-Backend:"
  done

Request 1:  X-Backend: A
Request 2:  X-Backend: B
Request 3:  X-Backend: A
Request 4:  X-Backend: B
Request 5:  X-Backend: A
Request 6:  X-Backend: B
Request 7:  X-Backend: A
Request 8:  X-Backend: B
Request 9:  X-Backend: A
Request 10: X-Backend: B
```

Both backends serve requests over HTTPS — round-robin load balancing confirmed.

---

## 5. Task D vs Task E Comparison

| Aspect | Task D (HTTP) | Task E (HTTPS) |
|--------|--------------|----------------|
| **Protocol** | HTTP | HTTPS (TLS) |
| **Port** | 8080 | 8443 |
| **Encryption** | None | TLSv1.3 (CHACHA20-POLY1305) |
| **Certificate** | N/A | mkcert CA-signed, SAN: app.teamX.test |
| **Request flow** | HTTP → nginx → backend | HTTPS → TLS termination at nginx → HTTP upstream → backend |
| **curl flags** | None needed | No `-k` needed (CA trusted) |
| **Load balancing** | ✅ Round-robin A/B | ✅ Round-robin A/B |
| **Response** | 200 OK | 200 OK |

### Both endpoints working simultaneously

```bash
# Task D
$ curl -i http://app.teamX.test:8080/api/status   → 200 OK, X-Backend: B

# Task E
$ curl -i https://app.teamX.test:8443/api/status   → 200 OK, X-Backend: A
```

> The backends do NOT run HTTPS. TLS terminates at nginx on Mac 2.

---

## Files Created

| File | Purpose |
|------|---------|
| `evidence/05-tls/mac1-client-verification.md` | Complete test output evidence |
| `evidence/05-tls/mac1-certificate-trust.md` | CA installation and trust evidence |
| `docs/phase1/task-e-client.md` | This document — client-side Task E documentation |
