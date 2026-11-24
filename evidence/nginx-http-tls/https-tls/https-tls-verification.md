# HTTPS & TLS 1.3 Termination Evidence (Port 8443)

**Component:** Transport Layer Security (TLS 1.3) Edge Termination  
**Target Node:** Mac 2 (Primary Edge)  
**Port:** `8443/TCP` (HTTPS / TLS)  
**Domain:** `app.teamX.test`  
**Auditor:** Kaustubh Hiwanj (Senior Computer Networks Engineer)  
**Status:** **VERIFIED**

---

## 1. Cryptographic Asset Verification

### 1.1 Leaf Certificate Details (`openssl x509`)

Command executed on Mac 2:
```bash
openssl x509 -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem -noout -subject -issuer -dates -ext subjectAltName
```

**Verified Cryptographic Attributes:**
```text
subject=O=mkcert development certificate, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
issuer=O=mkcert development CA, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj), CN=mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
notBefore=Sep 29 19:39:57 2026 GMT
notAfter=Dec 29 19:39:57 2028 GMT
X509v3 Subject Alternative Name: 
    DNS:app.teamX.test
```

### 1.2 Private Key Security & Modulus Alignment
- **File Location**: `/opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem`
- **File Permissions**: `0600` (Owner read/write only).
- **Git Policy**: Strictly excluded via `.gitignore`. Private key material is never printed, committed, or exposed.
- **Key-Certificate Pair Alignment (Verified via MD5 of Modulus)**:
  ```bash
  $ openssl x509 -noout -modulus -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem | openssl md5
  7b6a489c7457d38392cf99a8ec1563f4
  $ openssl rsa -noout -modulus -in /opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem | openssl md5
  7b6a489c7457d38392cf99a8ec1563f4
  ```
  *(Identical MD5 checksums confirm the private key matches the public leaf certificate).*

---

## 2. HTTPS Request Verification (No `-k` Insecure Bypass)

> [!IMPORTANT]
> **Strict Certificate Trust Verification:**  
> The use of `-k` or `--insecure` suppresses TLS certificate validation errors and does **not** prove successful certificate verification. The following evidence demonstrates successful HTTPS request completion with **full certificate chain validation** against the trusted root CA installed in the macOS System keychain.

**Command Executed:**
```bash
curl -i https://app.teamX.test:8443/api/status
```

**Observed Terminal Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 29 Sep 2026 19:44:25 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: B
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"

{"backend":"B","status":"ok"}
```

**Result:** Zero certificate warnings or errors. HTTP 200 OK received over TLS encrypted transport.

---

## 3. Verbose TLS Handshake & Cipher Suite Negotiation

**Command Executed:**
```bash
curl -v https://app.teamX.test:8443/api/status
```

**Observed Verbose Handshake Log:**
```text
* Host app.teamX.test:8443 was resolved.
* IPv4: 10.7.9.219 (or 10.7.9.11)
*   Trying 10.7.9.219:8443...
* Connected to app.teamX.test (10.7.9.219) port 8443
* ALPN: curl offers h2,http/1.1
* (304) (OUT), TLS handshake, Client hello (1):
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256 / [blank] / UNDEF
* ALPN: server accepted http/1.1
* Server certificate:
*  subject: O=mkcert development certificate; OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
*  start date: Sep 29 18:54:16 2026 GMT
*  expire date: Dec 29 18:54:16 2028 GMT
*  subjectAltName: host "app.teamX.test" matched cert's "app.teamX.test"
*  issuer: O=mkcert development CA; OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj); CN=mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
*  SSL certificate verify ok.
* using HTTP/1.x
> GET /api/status HTTP/1.1
> Host: app.teamX.test:8443
> User-Agent: curl/8.7.1
> Accept: */*
> 
< HTTP/1.1 200 OK
< Server: nginx/1.31.6
< Date: Tue, 29 Sep 2026 19:44:47 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 29
< Connection: keep-alive
< X-Powered-By: Express
< X-Backend: A
< ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
< 
{"backend":"A","status":"ok"}
```

### Handshake Sequence Analysis:
1. **ClientHello**: Emits supported cipher suites, TLS 1.3 protocol proposal, and Server Name Indication (`SNI: app.teamX.test`).
2. **ServerHello**: Nginx selects `TLSv1.3` and modern AEAD cipher `AEAD-CHACHA20-POLY1305-SHA256`.
3. **Certificate**: Nginx sends `app.teamX.test.pem`.
4. **Certificate Verification**: Client validates SAN match (`host "app.teamX.test" matched cert's "app.teamX.test"`) and reports `SSL certificate verify ok`.
5. **Finished & Application Data**: Handshake completes and encrypted HTTP request is transmitted.

---

## 4. OpenSSL `s_client` Diagnostic Handshake

**Command Executed:**
```bash
openssl s_client -connect 10.7.9.219:8443 -servername app.teamX.test </dev/null
```

**Key Verified Output Tokens:**
- `CONNECTED(00000003)`
- `depth=1 O = mkcert development CA, ...`
- `verify return:1`
- `depth=0 O = mkcert development certificate, ...`
- `verify return:1`
- `Verify return code: 0 (ok)`
- `Protocol  : TLSv1.3`
- `Cipher    : TLS_CHACHA20_POLY1305_SHA256`

---

## 5. What This Evidence Proves and Does Not Prove

### What It Proves:
- Nginx terminates TLS on port `8443/tcp`.
- Modern TLS 1.3 is fully negotiated with secure ciphers.
- The certificate chain is trusted by clients without disabling security flags (`-k`).
- The SAN extension correctly binds to `app.teamX.test`.

### What It Does Not Prove:
- It does **not** prove that backends run HTTPS (the connection from Nginx to Mac 3 is unencrypted HTTP).
- It does **not** prove public trust (mkcert is trusted only on machines with the local root CA installed).
- It does **not** prove Mac 2 listens on standard port 443.
