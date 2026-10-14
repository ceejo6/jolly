# Jolly 🍿

> A minimalist, air-gapped, self-hosted media ecosystem and control plane engineered for rapid deployment, zero operational bloat, and total data sovereignty.

---

## 1. Vision & Architecture

Jolly bridges a high-performance, air-gapped media server with a modern Rails 8 control plane running on self-hosted commodity hardware.

### Architectural Core
* **Jellyfin Engine:** Hardware-accelerated (Intel Quick Sync) offline media streaming, Kodi-compatible local `.nfo` metadata parsing, and UDP client auto-discovery.
* **Rails 8 Control Plane:** Application hub powered by modern Rails conventions—adopting the native SQLite **Solid Suite** (`solid_cache`, `solid_queue`, `solid_cable`) in Write-Ahead Logging (WAL) mode.
* **Zero-Touch Runtime:** Unified container orchestration where host system mounts, media files, databases, and caches sit behind an immutable directory boundary.
* **Autonomous & Resilient:** Designed to run 100% offline within a local home network, with optional remote egress provisioned via secure overlay networks (Tailscale & Cloudflare Tunnels).

---

## 2. Engineering Discipline: The 4-Branch Lifecycle

Every milestone in Jolly progresses through four strict, linear verification gates before code is promoted:

1. **The Contract:** Immutable requirements, schemas, and port boundaries.
2. **The Harness:** Single-verdict bash test suite (`PASS` / `FAILED`).
3. **The Outline:** Pre-code design blueprint audited against Contract & Harness.
4. **The Version:** Source code execution & verification against the frozen Harness.

---

## 3. Certified Milestones

### Milestone 0.1: Container Runtime Baseline
* **Status:** FROZEN & VERIFIED (Tag: `v0.1`)
* **Harness:** `scripts/test-0.1.sh`
* **Accomplishments:**
  * Unified storage hierarchy (`data/rails/`, `data/jellyfin/`, `data/media/`).
  * Enforced Git isolation rules for `.env` and `data/`.
  * Modern Compose specification without deprecated syntax.
  * Container memory limits and bridge networking (`jolly_network`).

### Milestone 0.2: Jellyfin Offline Media Layer
* **Status:** FROZEN & VERIFIED (Tag: `v0.2`)
* **Harness:** `scripts/test-0.2.sh`
* **Accomplishments:**
  * Deterministic directory schema for movies and TV series.
  * Local-first `.nfo` XML parsing and artwork fallback for 100% air-gapped playback.
  * UDP broadcast discovery listener over port `7359/udp`.
  * Automated synthetic media fixture validation.

---

## 4. Local Verification

To run regression tests on the host:

```bash
# Verify runtime baseline
./scripts/test-0.1.sh

# Verify offline media engine
./scripts/test-0.2.sh

---

## Milestone 0.3: Rails 8 & Solid Stack Engine

* **Status:** `FROZEN & VERIFIED` (Tag: `v0.3`)
* **Harness:** `scripts/test-0.3.sh`

### Accomplishments
* Replaced temporary Nginx stub with production Rails 8 API engine powered by Puma.
* Established multi-database SQLite layout in Write-Ahead Logging (WAL) mode targeting `./data/rails/storage`.
* Integrated full **Solid Suite** (`solid_cache`, `solid_queue`, `solid_cable`), removing all Redis and external queuing dependencies.
* Certified native `GET /up` Puma health check and multi-stage container build.

---

## Complete Regression Suite

Run all certified milestone regression harnesses on the host at any time:

bash
./scripts/test-0.1.sh  # Baseline container runtime
./scripts/test-0.2.sh  # Jellyfin media layer & air-gap persistence
./scripts/test-0.3.sh  # Rails 8 & Solid Stack engine

---

## Milestone 0.4: Remote Mesh & Secure Ingress

* **Status:** `FROZEN & VERIFIED` (Tag: `v0.4`)
* **Harness:** `scripts/test-0.4.sh`

### Accomplishments
* Architected dual-track ingress: Tailscale WireGuard mesh for high-throughput media streaming and Cloudflare Tunnel for edge-authenticated web traffic.
* Enforced token resilience: `jolly_tunnel` and `jolly_tailscale` operate in graceful standby during local/offline testing without crash looping.
* Validated internal bridge DNS resolution and container-to-container reachability over `jolly_network`.
* Confirmed zero regressions across baseline orchestration, media engine, and Rails 8 runtime.

---

## Complete Regression Suite

Run all certified milestone regression harnesses on the host at any time:

```bash
./scripts/test-0.1.sh  # Baseline container runtime
./scripts/test-0.2.sh  # Jellyfin media layer & air-gap persistence
./scripts/test-0.3.sh  # Rails 8 & Solid Stack engine
./scripts/test-0.4.sh  # Dual-track ingress & internal mesh

---

## Milestone 0.5: Hardware Transcoding Cutover (Intel QSV UHD 630)

* **Status:** `FROZEN & VERIFIED` (Tag: `v0.5`)
* **Harness:** `scripts/test-0.5.sh`

### Accomplishments
* Configured `/dev/dri` hardware device mapping and supplementary group permissions for Intel Quick Sync Video (Coffee Lake UHD 630).
* Certified automated headless synthetic video transcoding using `jellyfin-ffmpeg` with graceful software decode/encode fallback in virtualized environments.
* Stabilized Puma and Rails 8 configuration with persistent SQLite storage, background task isolation, and `tmp/pids` container handling.
* Hardened Tailscale user-space networking and standby modes to eliminate crash loops when auth keys are unset.

---

## Complete Regression Suite

Run all certified milestone regression harnesses on the host at any time:

```bash
./scripts/test-0.1.sh  # Baseline container runtime
./scripts/test-0.2.sh  # Jellyfin media layer & air-gap persistence
./scripts/test-0.3.sh  # Rails 8 & Solid Stack engine
./scripts/test-0.4.sh  # Dual-track ingress & internal mesh
./scripts/test-0.5.sh  # Intel QSV transcoding pipeline

---

## Milestone 1.0: Unified Production Bare-Metal Release

* **Status:** `FROZEN & VERIFIED` (Tag: `v1.0`)
* **Master Harness:** `scripts/test-1.0.sh`

### Accomplishments
* Built unified zero-touch bare-metal installer (`install.sh`) for automated deployment on Ubuntu 24.04 Server.
* Integrated systemd unit (`jolly.service`) providing OS-level daemon orchestration, auto-boot on physical host power-on, and clean SQLite transaction flushing on host shutdown.
* Established master acceptance test suite validating installation scripts, systemd configurations, mount permissions, and cumulative multi-version regressions.

---

## Bare-Metal Physical Host Deployment

To deploy Project Jolly to a dedicated physical Ubuntu 24.04 server (Intel i5-8400, UHD 630):

```bash
# 1. Clone repository on target host
git clone [https://github.com/ceejo6/jolly.git](https://github.com/ceejo6/jolly.git) /opt/jolly
cd /opt/jolly

# 2. Run the automated installer with root privileges
sudo ./install.sh
