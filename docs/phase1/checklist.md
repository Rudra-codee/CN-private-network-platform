# Phase 1 Execution Checklist

This practical checklist tracks step-by-step progress for completing and verifying Phase 1 requirements.

## LAN Setup & Verification
- [x] All 4 Macs on same private LAN
- [x] IP addresses recorded
- [x] Prefix/subnet recorded
- [x] Gateway recorded
- [x] Network interface recorded
- [x] MAC addresses recorded
- [x] All tested machine pairs can communicate with ping
- [x] Topology diagram completed

## DNS Configuration & Verification
- [x] dnsmasq configured on Mac 1
- [x] app.teamX.test resolves to Mac 2
- [x] api.teamX.test resolves to Mac 2
- [x] At least two client Macs use Mac 1 as DNS resolver
- [x] dig/nslookup evidence collected

## Backend Services
- [x] Backend A runs on 3001
- [x] Backend B runs on 3002
- [x] GET / works
- [x] GET /api/status works
- [x] X-Backend header works
- [x] Backends are LAN-accessible

## nginx Edge & Load Balancing
- [x] nginx installed on Mac 2
- [x] nginx configuration created
- [x] nginx configuration validated
- [x] nginx listening on port 8080
- [x] Backend A reachable
- [x] Backend B reachable
- [x] Reverse proxy working
- [x] app.teamX.test reaches nginx
- [x] Backend A returned through nginx
- [x] Backend B returned through nginx
- [x] Round-robin behavior demonstrated
- [x] Evidence documented

## TLS / HTTPS
- [ ] Certificate generated
- [ ] nginx terminates TLS
- [ ] Client trusts certificate
- [ ] HTTPS works
- [ ] Demo does not use curl -k
- [ ] TLS handshake captured

## HTTP Caching Behavior
- [x] Cache-Control header configured
- [x] curl -I evidence captured
- [x] Cache hit or 304 demonstrated

## Packet Capture & Analysis
- [ ] DNS query/response captured
- [ ] TCP SYN/SYN-ACK/ACK captured
- [ ] TLS handshake captured
- [ ] Encrypted application data identified
- [ ] Source/destination ports identified

## Required Failure Scenarios
- [ ] Wrong DNS server
- [ ] Wrong DNS record
- [ ] One backend stopped
- [ ] Both backends stopped
- [ ] Wrong destination port
