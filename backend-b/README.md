# Backend Service B

## Machine Information
- **Machine**: Mac 4
- **Current IPv4 Address**: `10.7.29.244` (assigned via DHCP; previous address `10.7.11.88` is no longer current)
- **Role**: Backend Server B + Test Client
- **Port**: `3002` (TCP)
- **Host Binding**: `0.0.0.0`

## Host Binding Rationale (`0.0.0.0`)
Binding the server to `0.0.0.0` rather than `127.0.0.1` (loopback) is strictly required because Backend B must be reachable across the private LAN from other machines—specifically Mac 2 (the edge reverse proxy and load balancer). If bound only to `127.0.0.1`, the service would accept connections only originating locally on Mac 4, blocking upstream traffic from the reverse proxy.

## Tech Stack
- **Runtime**: Node.js
- **Framework**: Express

## Endpoints

### 1. `GET /`
- **Purpose**: General service health and identity confirmation
- **Response Code**: `200 OK`
- **Response Headers**: `X-Backend: B`
- **Response Body**:
  ```json
  {
    "backend": "B",
    "status": "ok",
    "message": "Backend B is running"
  }
  ```

### 2. `GET /api/status`
- **Purpose**: Primary status and backend identification endpoint for reverse proxy upstream health checks and load balancer routing
- **Response Code**: `200 OK`
- **Response Headers**: `X-Backend: B`
- **Response Body**:
  ```json
  {
    "backend": "B",
    "status": "ok"
  }
  ```

## Running the Service

### 1. Install Dependencies
```bash
npm install
```

### 2. Start Service
```bash
npm start
```
Starts `server.js` using Node.js:
```
Backend B listening on 0.0.0.0:3002
```

## Verification Commands

### Local Verification
```bash
curl -i http://127.0.0.1:3002/
curl -i http://127.0.0.1:3002/api/status
```

### LAN Verification
```bash
curl -i http://10.7.29.244:3002/api/status
```

### Port Listener Check
```bash
sudo lsof -nP -iTCP:3002 -sTCP:LISTEN
```
