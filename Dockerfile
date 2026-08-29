# syntax=docker/dockerfile:1

# Self-hosted OSRM router for QuickFlick — Northern India extract
# (full Punjab, Haryana, Delhi, Rajasthan, UP, J&K, Himachal, Uttarakhand)
#
# The 222 MB Geofabrik PBF is downloaded + processed at BUILD time
# (never committed to git — GitHub's 100 MB file limit). The processed
# .osrm files (~1.4 GB) are baked into the image, so the container
# starts instantly and the data is versioned via the image tag.
#
# Update cadence: bump PBF_VERSION below when you want fresher OSM data
# (Geofabrik publishes daily; monthly is plenty for village deliveries).

ARG OSRM_IMAGE=ghcr.io/project-osrm/osrm-backend
ARG PBF_URL=https://download.geofabrik.de/asia/india/northern-zone-260827.osm.pbf

################################################################################
# Build stage — download + process the extract
################################################################################

FROM ${OSRM_IMAGE} AS osrm-build

ARG PBF_URL

# Base image is minimal Debian — no download tool included
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /data

# Download with retry, verify it's a valid PBF (magic bytes '0A0D0A'), then process:
#   osrm-extract   — parse PBF into routing graph         (~10-15 min)
#   osrm-partition — MLD partitioning for fast queries    (~2-5 min)
#   osrm-customize — precompute speed tables              (~2-5 min)
RUN set -eux; \
    wget --tries=3 --timeout=60 -q "${PBF_URL}" -O /data/extract.osm.pbf; \
    test "$(stat -c%s /data/extract.osm.pbf)" -gt 100000000 || (echo "PBF too small — download corrupted" && exit 1); \
    head -c 16 /data/extract.osm.pbf | od -An -c | grep -q "O   S   M   H" || (echo "Not a valid OSM PBF file" && exit 1); \
    osrm-extract -p /opt/car.lua /data/extract.osm.pbf; \
    osrm-partition /data/extract.osrm; \
    osrm-customize /data/extract.osrm; \
    rm -f /data/extract.osm.pbf

################################################################################
# Runtime stage — serve the processed graph
################################################################################

FROM ${OSRM_IMAGE}

# Copy the full processed graph file set (extract.osrm is the master,
# the others are sidecar files osrm-routed needs: .geometry, .nodes, etc.)
COPY --from=osrm-build /data/ /data/

ENV OSRM_DATA=/data/extract.osrm \
    OSRM_ALGORITHM=mld \
    OSRM_PORT=5000

EXPOSE 5000

# --algorithm mld is required for partitioned graphs (CH is the default)
CMD ["sh", "-c", "osrm-routed --algorithm ${OSRM_ALGORITHM} --port ${OSRM_PORT} /data/extract.osrm"]