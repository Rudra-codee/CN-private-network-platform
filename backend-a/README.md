# Backend Service A

## Overview
Backend Service A is an Express-based Node.js service running on Mac 3 (10.7.13.5). It serves as one of the upstream application backends in the private network architecture.

## Configuration
- **Machine**: Mac 3
- **IP Address**: `10.7.13.5`
- **Host Binding**: `0.0.0.0` (binds to all network interfaces so it can be reached across the LAN)
- **Port**: `3001` (TCP)
- **Framework**: Node.js + Express

## Why 0.0.0.0 Host Binding is Required
Binding to `0.0.0.0` ensures the server listens on all network interfaces rather than localhost (`127.0.0.1`) only. This is required so that external LAN machines—specifically Mac 2 (`10.7.9.11`), which acts as the Nginx reverse proxy/load balancer—can forward HTTP requests to Backend A across the network.

## Endpoints & Expected Behaviors

### 1. `GET /`
- **HTTP Status**: `200 OK`
- **Headers**: `X-Backend: A`
- **Response Body**:
  ```json
  {
    "backend": "A",
    "status": "ok",
    "message": "Backend A is running"
  }
  ```

### 2. `GET /api/status`
- **HTTP Status**: `200 OK`
- **Headers**: `X-Backend: A`
- **Response Body**:
  ```json
  {
    "backend": "A",
    "status": "ok"
  }
  ```

## How to Run

1. **Install Dependencies**:
   ```bash
   npm install
   ```

2. **Start Backend A**:
   ```bash
   npm start
   ```
   *The server will start listening on `0.0.0.0:3001`.*

## Verification Commands

### Local Loopback Tests
```bash
curl -i http://127.0.0.1:3001/
curl -i http://127.0.0.1:3001/api/status
```

### LAN Interface Test
```bash
curl -i http://10.7.13.5:3001/api/status
```

### Socket Listener Verification
```bash
lsof -nP -iTCP:3001 -sTCP:LISTEN
```
