# Task E — HTTPS / TLS Client Verification (Mac 1)

**Date:** 2026-09-30  
**Machine:** Mac 1 (10.7.17.222)  
**Role:** Private DNS Server + Test Client  
**Tested against:** nginx on Mac 2 (10.7.9.11:8443)

---

## 1. System DNS Configuration

Mac 1's Wi-Fi DNS is set to its own dnsmasq server:

```
$ networksetup -getdnsservers Wi-Fi
10.7.17.222
```

**Result:** ✅ PASS — Mac 1 uses its own dnsmasq for DNS resolution.

---

## 2. DNS Cache Flushed

```
$ sudo dscacheutil -flushcache
$ sudo killall -HUP mDNSResponder
```

**Result:** ✅ PASS — DNS cache cleared before testing.

---

## 3. Project DNS Resolution (System DNS)

### app.teamX.test

```
$ dig app.teamX.test

; <<>> DiG 9.10.6 <<>> app.teamX.test
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 65162
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;app.teamX.test.            IN  A

;; ANSWER SECTION:
app.teamX.test.     0   IN  A   10.7.9.11

;; Query time: 2 msec
;; SERVER: 10.7.17.222#53(10.7.17.222)
;; WHEN: Wed Sep 30 01:11:02 IST 2026
;; MSG SIZE  rcvd: 59
```

**Result:** ✅ PASS  
- Status: NOERROR  
- Answer: `10.7.9.11`  
- Server: `10.7.17.222#53` (system DNS, not `@` override)

### api.teamX.test

```
$ dig api.teamX.test

; <<>> DiG 9.10.6 <<>> api.teamX.test
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 15185
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;api.teamX.test.            IN  A

;; ANSWER SECTION:
api.teamX.test.     0   IN  A   10.7.9.11

;; Query time: 2 msec
;; SERVER: 10.7.17.222#53(10.7.17.222)
;; WHEN: Wed Sep 30 01:11:12 IST 2026
;; MSG SIZE  rcvd: 59
```

**Result:** ✅ PASS  
- Status: NOERROR  
- Answer: `10.7.9.11`  
- Server: `10.7.17.222#53`

> **Note:** Neither query used `dig @10.7.17.222`. This proves Mac 1's system DNS is configured to use dnsmasq.

---

## 4. Internet DNS (Upstream Forwarding)

```
$ dig google.com

; <<>> DiG 9.10.6 <<>> google.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 30839
;; flags: qr rd ra; QUERY: 1, ANSWER: 6, AUTHORITY: 0, ADDITIONAL: 1

;; ANSWER SECTION:
google.com.     297 IN  A   192.178.158.139
google.com.     297 IN  A   192.178.158.113
google.com.     297 IN  A   192.178.158.102
google.com.     297 IN  A   192.178.158.101
google.com.     297 IN  A   192.178.158.138
google.com.     297 IN  A   192.178.158.100

;; Query time: 106 msec
;; SERVER: 10.7.17.222#53(10.7.17.222)
;; WHEN: Wed Sep 30 01:11:14 IST 2026
;; MSG SIZE  rcvd: 135
```

**Result:** ✅ PASS  
- Status: NOERROR  
- Server: `10.7.17.222#53` (dnsmasq forwards non-project domains upstream)

---

## 5. HTTPS Without `-k` (Certificate Validation)

```
$ curl -i https://app.teamX.test:8443/api/status
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 29 Sep 2026 19:41:35 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"

{"backend":"A","status":"ok"}
```

**Result:** ✅ PASS  
- HTTP 200 OK  
- Server: nginx/1.31.6  
- X-Backend: A  
- **No `-k` flag used** — certificate validated against trusted CA  
- No certificate errors

---

## 6. Verbose TLS Connection

```
$ curl -v https://app.teamX.test:8443/api/status
* Host app.teamX.test:8443 was resolved.
* IPv6: (none)
* IPv4: 10.7.9.11
*   Trying 10.7.9.11:8443...
* Connected to app.teamX.test (10.7.9.11) port 8443
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
* Request completely sent off
< HTTP/1.1 200 OK
< Server: nginx/1.31.6
< Date: Tue, 29 Sep 2026 19:41:43 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 29
< Connection: keep-alive
< X-Powered-By: Express
< X-Backend: B
< ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"
<
* Connection #0 to host app.teamX.test left intact
{"backend":"B","status":"ok"}
```

### TLS Handshake Breakdown

| Step | Description |
|------|-------------|
| **ClientHello** | Client sends supported cipher suites and TLS versions |
| **ServerHello** | Server selects TLSv1.3 with AEAD-CHACHA20-POLY1305-SHA256 |
| **Certificate** | Server sends mkcert-generated certificate for `app.teamX.test` |
| **CERT verify** | Client verifies certificate chain against trusted CA in System keychain |
| **Finished** | Both sides confirm handshake parameters |
| **Application data** | Encrypted HTTP traffic begins (GET /api/status) |

**Key observations:**
- **TLS Version:** TLSv1.3
- **Cipher:** AEAD-CHACHA20-POLY1305-SHA256
- **Certificate SAN match:** `app.teamX.test` matched cert's `app.teamX.test`
- **SSL certificate verify ok** — no errors, no `-k` bypass
- **TLS termination:** at nginx on Mac 2 (10.7.9.11)

---

## 7. HTTPS Load Balancing

```
$ for i in {1..10}; do
    echo "Request $i"
    curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null \
      | grep -i "X-Backend:"
  done

Request 1
X-Backend: A
Request 2
X-Backend: B
Request 3
X-Backend: A
Request 4
X-Backend: B
Request 5
X-Backend: A
Request 6
X-Backend: B
Request 7
X-Backend: A
Request 8
X-Backend: B
Request 9
X-Backend: A
Request 10
X-Backend: B
```

**Result:** ✅ PASS  
- Both Backend A and Backend B appear across requests  
- nginx round-robin load balancing confirmed over HTTPS

---

## 8. Root Endpoint (HTTPS)

```
$ curl -i https://app.teamX.test:8443/
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 29 Sep 2026 19:41:47 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 62
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"3e-QF9vFacPifwgRXeqh9wcQA56VjA"

{"backend":"A","status":"ok","message":"Backend A is running"}
```

**Result:** ✅ PASS  
- HTTP 200 OK  
- Server: nginx/1.31.6  
- X-Backend: A  

---

## 9. Task D vs Task E Comparison

### Task D — HTTP (port 8080)

```
$ curl -i http://app.teamX.test:8080/api/status
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 29 Sep 2026 19:41:56 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: B
ETag: W/"1d-eqo46f6cZTMyh8pAIw5ntQG78PA"

{"backend":"B","status":"ok"}
```

### Task E — HTTPS (port 8443)

```
$ curl -i https://app.teamX.test:8443/api/status
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 29 Sep 2026 19:41:56 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: A
ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"

{"backend":"A","status":"ok"}
```

### Comparison

| Aspect | Task D (HTTP) | Task E (HTTPS) |
|--------|--------------|----------------|
| Protocol | HTTP | HTTPS (TLS) |
| Port | 8080 | 8443 |
| Encryption | None | TLSv1.3 |
| Certificate | N/A | mkcert CA-signed |
| Flow | HTTP → nginx → backend | HTTPS → TLS termination at nginx → HTTP upstream → backend |
| Load balancing | ✅ Round-robin | ✅ Round-robin |
| Status | 200 OK | 200 OK |

> **Important:** The backends themselves do NOT run HTTPS. TLS terminates at nginx on Mac 2. nginx then proxies to backends over plain HTTP.

---

## Summary

| Test | Status |
|------|--------|
| System DNS set to 10.7.17.222 | ✅ PASS |
| DNS cache flushed | ✅ PASS |
| app.teamX.test resolves to 10.7.9.11 | ✅ PASS |
| api.teamX.test resolves to 10.7.9.11 | ✅ PASS |
| Internet DNS (google.com) works | ✅ PASS |
| CA trusted in System keychain | ✅ PASS |
| HTTPS 200 OK without `-k` | ✅ PASS |
| TLS handshake verified (TLSv1.3) | ✅ PASS |
| Certificate SAN matches hostname | ✅ PASS |
| SSL certificate verify ok | ✅ PASS |
| HTTPS load balancing (A + B) | ✅ PASS |
| Root endpoint HTTPS | ✅ PASS |
| Task D HTTP still works | ✅ PASS |
| Task D vs Task E documented | ✅ PASS |
