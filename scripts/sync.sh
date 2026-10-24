#!/usr/bin/env bash
# Sync the TWRP sources (minimal manifest, twrp-14.1) into src/, in the titan2-aosp container
# (repo and python from the image: the host python may not match).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ROOT/src" "$ROOT/work/home"
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/home/builder \
  -v "$ROOT/work/home:/home/builder" -v "$ROOT/src:/src" -w /src titan2-aosp bash -euo pipefail -c '
git config --global user.name serlk; git config --global user.email 22211586+Serlk@users.noreply.github.com
git config --global color.ui false; git lfs install >/dev/null
[ -d .repo/manifests ] || repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git \
  -b twrp-14.1 --git-lfs --depth=1
repo sync -c -j8 --force-sync --no-tags --no-clone-bundle --optimized-fetch --prune --fail-fast
echo SYNC_DONE
'
