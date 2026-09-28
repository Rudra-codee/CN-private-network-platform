# Phase 1 Execution Checklist

This practical checklist tracks step-by-step progress for completing and verifying Phase 1 requirements.

## LAN Setup & Verification
- [ ] All 4 Macs on same private LAN
- [ ] IP addresses recorded
- [ ] Prefix/subnet recorded
- [ ] Gateway recorded
- [ ] Network interface recorded
- [ ] MAC addresses recorded
- [ ] All machines can ping each other
- [ ] Topology diagram completed

## DNS Configuration & Verification
- [ ] dnsmasq configured on Mac 1
- [ ] app.teamX.test resolves to Mac 2
- [ ] api.teamX.test resolves to Mac 2
- [ ] At least two client Macs use Mac 1 as DNS resolver
- [ ] dig/nslookup evidence collected

## Backend Services
- [ ] Backend A runs on 3001
- [ ] Backend B runs on 3002
- [ ] GET / works
- [ ] GET /api/status works
- [ ] X-Backend header works
- [ ] Backends are LAN-accessible

## nginx Edge & Load Balancing
- [ ] nginx runs on Mac 2
- [ ] Reverse proxy configured
- [ ] Load balancing configured
- [ ] Requests reach Backend A
- [ ] Requests reach Backend B
- [ ] X-Backend A/B demonstrated

## TLS / HTTPS
- [ ] Certificate generated
- [ ] nginx terminates TLS
- [ ] Client trusts certificate
- [ ] HTTPS works
- [ ] Demo does not use curl -k
- [ ] TLS handshake captured

## HTTP Caching Behavior
- [ ] Cache-Control header configured
- [ ] curl -I evidence captured
- [ ] Cache hit or 304 demonstrated

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
