# quick-flick-osrm

Self-hosted OSRM (Open Source Routing Machine) router for QuickFlick —
**Northern India extract** (full Punjab, Haryana, Delhi, Rajasthan, UP,
J&K, Himachal, Uttarakhand), covering the launch village **Chuhriwala
Dhan near Abohar, Fazilka district, Punjab** (30.2126°N, 74.1347°E).

## Why self-hosted

The admin tracking map draws partner route polylines (partner → dark
store before pickup, partner → delivery address after pickup). The
public `router.project-osrm.org` demo server has no SLA and rate limits.
This gives QuickFlick its own routing API with identical semantics.

## How it works

- `Dockerfile` downloads the Geofabrik PBF (222 MB, northern zone) at
  **build time** and processes it (`osrm-extract` → `osrm-partition` →
  `osrm-customize`). The PBF and ~1.4 GB processed graph never touch
  git (GitHub's 100 MB per-file limit) — the data is versioned via the
  image tag instead.
- CI (`.github/workflows/docker-ci.yml`) builds on push to
  `staging`/`main`, pushes to Docker Hub, and updates the DCF repo
  compose file — same two-repo GitOps pattern as the other QuickFlick
  services.
- The container serves the standard OSRM HTTP API on port 5000 with
  the MLD algorithm.

## API

Same as public OSRM:

```
GET /route/v1/driving/{lng},{lat};{lng},{lat}?overview=full&geometries=geojson
```

Example (Chuhriwala Dhan → Abohar):

```
curl "http://osrm:5000/route/v1/driving/74.1347,30.2126;74.1957,30.1451?overview=false"
```

## Updating the map data

1. Pick a fresh extract from https://download.geofabrik.de/asia/india
   (e.g. `northern-zone-YYMMDD.osm.pbf`)
2. Update `PBF_URL` in `Dockerfile`
3. Commit to `development`, merge to `staging` — CI rebuilds the image
   (~15-30 min) and the DCF compose tag updates automatically

Monthly updates are plenty for village deliveries; roads change slowly.

## Smoke test coordinates

| Place | lat | lng |
|-------|-----|-----|
| Chuhriwala Dhan (village) | 30.2126 | 74.1347 |
| Abohar (nearest city) | 30.1451 | 74.1957 |

## Branches

- `development` (default) — working branch
- `staging` — CI builds `staging-*` images
- `main` — CI builds `main-*` images