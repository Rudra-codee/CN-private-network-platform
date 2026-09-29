# Task B — DNS Client Verification

This document records the verification that DNS client machines (Mac 2 and Mac 4) are correctly configured to use Mac 1 (10.7.17.222) as their DNS resolver and can resolve the project's private domains.

## Objective

Verify that at least two client Macs use Mac 1 as their DNS resolver and successfully resolve `app.teamX.test` and `api.teamX.test` to 10.7.9.11.

## DNS Client Configuration

| Machine | IPv4 | Configured DNS Server | Role |
|---|---|---|---|
| Mac 2 | 10.7.9.11 | 10.7.17.222 (Mac 1) | Edge / Reverse Proxy + Load Balancer |
| Mac 4 | 10.7.11.88 | 10.7.17.222 (Mac 1) | Backend B + Client |

Mac 3 was **not** configured as a DNS client for this task.

## Verification Results

### Mac 2 — Client Verification

Queries were executed on Mac 2 using `dig` without specifying a server (i.e., using the system-configured DNS resolver).

#### `dig app.teamX.test` (from Mac 2)

| Field | Value |
|---|---|
| Query | app.teamX.test |
| Server | 10.7.17.222#53 |
| Status | NOERROR |
| Answer | 10.7.9.11 |

#### `dig api.teamX.test` (from Mac 2)

| Field | Value |
|---|---|
| Query | api.teamX.test |
| Server | 10.7.17.222#53 |
| Status | NOERROR |
| Answer | 10.7.9.11 |

### Mac 4 — Client Verification

Queries were executed on Mac 4 using `dig` without specifying a server.

#### `dig app.teamX.test` (from Mac 4)

| Field | Value |
|---|---|
| Query | app.teamX.test |
| Server | 10.7.17.222#53 |
| Status | NOERROR |
| Answer | 10.7.9.11 |

#### `dig api.teamX.test` (from Mac 4)

| Field | Value |
|---|---|
| Query | api.teamX.test |
| Server | 10.7.17.222#53 |
| Status | NOERROR |
| Answer | 10.7.9.11 |

## Consolidated Verification Table

| Client | DNS Server | Domain | Result | Resolved IP |
|---|---|---|---|---|
| Mac 2 | 10.7.17.222 | app.teamX.test | PASS | 10.7.9.11 |
| Mac 2 | 10.7.17.222 | api.teamX.test | PASS | 10.7.9.11 |
| Mac 4 | 10.7.17.222 | app.teamX.test | PASS | 10.7.9.11 |
| Mac 4 | 10.7.17.222 | api.teamX.test | PASS | 10.7.9.11 |

## Commands Used

```bash
# Standard dig query using system-configured DNS resolver
dig app.teamX.test
dig api.teamX.test
```

When `dig` is run without the `@server` argument, it uses the DNS resolver configured in the system's network settings. The `SERVER` field in the dig output confirms which resolver handled the query. In both cases, the SERVER line reported `10.7.17.222#53`, confirming Mac 1 was used as the resolver.

## Observations

- Both Mac 2 and Mac 4 are confirmed to use Mac 1 (10.7.17.222) as their DNS resolver.
- All four queries returned `NOERROR` status and resolved to the correct IP address (10.7.9.11).
- The `SERVER` line in the dig output confirmed that queries were handled by `10.7.17.222#53` (Mac 1), not by any external DNS resolver.

## Conclusion

Two DNS client machines (Mac 2 and Mac 4) have been configured to use Mac 1 as their DNS resolver. All queries for `app.teamX.test` and `api.teamX.test` resolved correctly to 10.7.9.11 (Mac 2), satisfying the Task B client verification requirement.
