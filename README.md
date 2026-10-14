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
