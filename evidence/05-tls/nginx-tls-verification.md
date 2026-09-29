# Task E — nginx TLS Verification Evidence

This document records the empirical verification of HTTPS termination on port 8443 on Mac 2, full certificate trust validation without `-k`, verbose TLS 1.3 handshake negotiation logs, HTTPS load-balancing behavior, and Task D HTTP port 8080 regression testing.

## 1. Verified HTTPS Request (No `curl -k`)

**Command:**
```bash
curl -i https://app.teamX.test:8443/api/status
```

**Verified Output:**
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

**Result:** The client successfully connects over HTTPS on port 8443 with full certificate chain validation (zero certificate errors, without using `-k`).

---

## 2. Verbose TLS Handshake Verification Log

**Command:**
```bash
curl -v https://app.teamX.test:8443/api/status
```

**Verified Output Log:**
```
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
< Date: Tue, 29 Sep 2026 19:44:47 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 29
< Connection: keep-alive
< X-Powered-By: Express
< X-Backend: A
< ETag: W/"1d-/mMMZex8nvIDi44lSUobi0vFg/M"
< 
* Connection #0 to host app.teamX.test left intact
{"backend":"A","status":"ok"}
```

**Handshake Phase Analysis:**
- **ClientHello**: `(OUT), TLS handshake, Client hello (1)` sent with proposed ciphers and ALPN `h2,http/1.1`.
- **ServerHello**: `(IN), TLS handshake, Server hello (2)` returned selecting `TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256`.
- **Certificate**: `(IN), TLS handshake, Certificate (11)` sent delivering `app.teamX.test.pem`.
- **Key Exchange & Verify**: `(IN), TLS handshake, CERT verify (15)` verified against local CA root.
- **Finished**: `(IN)/(OUT), TLS handshake, Finished (20)` completed handshake.
- **Encrypted Application Data**: HTTP GET request transmitted over negotiated TLS session.

---

## 3. HTTPS Load-Balancing Verification (10 Requests)

**Command:**
```bash
for i in {1..10}; do
  echo "Request $i"
  curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null \
    | grep -i "X-Backend:"
done
```

**Verified Output:**
```
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

**Result:** Proves 10/10 successful load-balancing distribution over HTTPS on port 8443 across Backend A and Backend B.

---

## 4. Task D HTTP Port 8080 Regression Test

**Command:**
```bash
curl -i http://app.teamX.test:8080/api/status
```

**Verified Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Tue, 29 Sep 2026 19:45:00 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 29
Connection: keep-alive
X-Powered-By: Express
X-Backend: B

{"backend":"B","status":"ok"}
```

**Result:** Unencrypted HTTP proxying on port 8080 remains 100% operational alongside port 8443 HTTPS.
