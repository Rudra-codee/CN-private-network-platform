# Task B — DNS Server Verification

This document records the verification of the dnsmasq DNS server running on Mac 1, confirming that it is listening on the expected address and port and that it correctly resolves the project's private domains.

## Objective

Verify that the dnsmasq DNS server on Mac 1 (10.7.17.222) is operational and returns correct A records for `app.teamX.test` and `api.teamX.test`.

## Server Status

The DNS server process was confirmed listening on Mac 1 using `lsof`:

```bash
sudo lsof -i :53
```

This confirmed that `dnsmasq` was bound to `10.7.17.222:53` (UDP).

## DNS Server Query Verification

The following queries were executed directly against the DNS server on Mac 1 using the `@` syntax to specify the target resolver.

### `dig @10.7.17.222 app.teamX.test`

| Field | Value |
|---|---|
| Query | app.teamX.test |
| Server | 10.7.17.222#53 |
| Status | NOERROR |
| Answer | 10.7.9.11 |

### `dig @10.7.17.222 api.teamX.test`

| Field | Value |
|---|---|
| Query | api.teamX.test |
| Server | 10.7.17.222#53 |
| Status | NOERROR |
| Answer | 10.7.9.11 |

## Summary

| Domain | Server | Status | Resolved IP |
|---|---|---|---|
| app.teamX.test | 10.7.17.222#53 | NOERROR | 10.7.9.11 |
| api.teamX.test | 10.7.17.222#53 | NOERROR | 10.7.9.11 |

## Commands Used

```bash
# Query the DNS server directly for a specific domain
dig @10.7.17.222 app.teamX.test
dig @10.7.17.222 api.teamX.test

# Verify DNS process is listening on port 53
sudo lsof -i :53
```

- `dig @<server> <domain>` sends a DNS query to the specified server and displays the response, including status, answer section, and the server that responded.
- `lsof -i :53` lists processes with open sockets on port 53, confirming that dnsmasq is bound and listening.

## Conclusion

The dnsmasq DNS server on Mac 1 (10.7.17.222) correctly resolves both `app.teamX.test` and `api.teamX.test` to 10.7.9.11 (Mac 2). The server is confirmed listening on port 53/UDP.
