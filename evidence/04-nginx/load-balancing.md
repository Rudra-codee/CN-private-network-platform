# Task D — Load Balancing Verification

This document records the automated verification of round-robin load balancing performed by nginx on Mac 2 across Backend A (`10.7.13.5:3001`) and Backend B (`10.7.29.244:3002`).

## Objective

Verify that sequential HTTP requests directed to `http://app.teamX.test:8080/api/status` are evenly and deterministically distributed between Backend A and Backend B according to nginx's default round-robin load balancing strategy.

## Verification Script

The following shell loop was executed to send 10 consecutive HTTP requests to the edge proxy while extracting the `X-Backend:` header from each HTTP response:

```bash
for i in {1..10}; do
  echo "Request $i"
  curl -s -D - http://app.teamX.test:8080/api/status -o /dev/null \
    | grep -i "X-Backend:"
done
```

## Verified Output Log

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

## Statistical & Functional Analysis

| Metric | Result |
|---|---|
| Total Requests Sent | 10 |
| Total Responses Received | 10 (100% Success Rate) |
| Backend A Count | 5 (50%) |
| Backend B Count | 5 (50%) |
| Distribution Pattern | Perfect Strict Alternation (`A` → `B` → `A` → `B` ...) |
| Load Balancing Algorithm | Round-Robin |

## Conclusion

The 10-request loop demonstrates a 10/10 successful distribution test. nginx on Mac 2 correctly alternates incoming traffic between Backend A (`10.7.13.5:3001`) and Backend B (`10.7.29.244:3002`), proving that the `upstream backend_pool` round-robin load balancing configuration is fully functional.
