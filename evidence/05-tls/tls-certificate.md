# Task E — TLS Certificate Verification

This document records the certificate generation details and Subject Alternative Name (SAN) validation for `app.teamX.test`.

## Objective

Generate a trusted local X.509 TLS certificate for `app.teamX.test` using `mkcert` and verify certificate subject, issuer, and SAN extensions using `openssl`.

## Certificate Generation Log

**Command executed:**
```bash
mkdir -p /opt/homebrew/etc/nginx/certs
cd /opt/homebrew/etc/nginx/certs
mkcert app.teamX.test
```

**Output:**
```
Created a new certificate valid for the following names 📜
 - "app.teamX.test"

The certificate is at "./app.teamX.test.pem" and the key at "./app.teamX.test-key.pem" ✅

It will expire on 30 December 2028 🗓
```

## OpenSSL Certificate Inspection

**Verification command:**
```bash
openssl x509 \
  -in /opt/homebrew/etc/nginx/certs/app.teamX.test.pem \
  -noout \
  -subject \
  -issuer \
  -ext subjectAltName
```

**Verified Output:**
```
subject=O=mkcert development certificate, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
issuer=O=mkcert development CA, OU=kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj), CN=mkcert kaustubhhiwanj@Kaustubhs-MacBook-Pro-2.local (Kaustubh Hiwanj)
X509v3 Subject Alternative Name: 
    DNS:app.teamX.test
```

## Certificate File Inventory

| File Path | Description | Commit Status |
|---|---|---|
| `/opt/homebrew/etc/nginx/certs/app.teamX.test.pem` | Public TLS X.509 Certificate | Local deployment |
| `/opt/homebrew/etc/nginx/certs/app.teamX.test-key.pem` | Private Key File | **EXCLUDED** (`.gitignore`) |

## CA Root Location for Client Installation

```bash
mkcert -CAROOT
# Path: /Users/kaustubhhiwanj/Library/Application Support/mkcert
```

Client machines (Mac 1 and Mac 4) require `rootCA.pem` from this directory to validate `https://app.teamX.test:8443` without `-k`.
