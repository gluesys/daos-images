#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# Put the Versity gateway source (exastor/versitygw, the fork carrying the
# native DAOS backend) into the build context at images/versitygw/src, so the
# Dockerfile never needs registry or git credentials.
#
#   scripts/fetch-versitygw.sh [ref]              # clone the fork at <ref>
#   VGW_SRC=/path/to/checkout scripts/fetch-versitygw.sh   # use a local tree
#
# In CI, VGW_REPO carries the token form (https://gitlab-ci-token:$CI_JOB_TOKEN@...).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/images/versitygw/src"
ref="${1:-${VGW_REF:-feature/daos-backend}}"
repo="${VGW_REPO:-git@gitlab.gluesys.com:exastor/versitygw.git}"

rm -rf "$dest"
if [ -n "${VGW_SRC:-}" ]; then
  # a local checkout: copy what git tracks, so build artifacts stay out
  test -d "$VGW_SRC/.git" || { echo "VGW_SRC=$VGW_SRC is not a git checkout" >&2; exit 1; }
  mkdir -p "$dest"
  git -C "$VGW_SRC" archive --format=tar "${VGW_SRC_REF:-HEAD}" | tar -x -C "$dest"
  echo "versitygw source from $VGW_SRC @ $(git -C "$VGW_SRC" rev-parse --short "${VGW_SRC_REF:-HEAD}")"
else
  git clone --depth 1 --branch "$ref" "$repo" "$dest" >/dev/null 2>&1 || {
    # --branch also takes tags but not arbitrary SHAs; fall back to fetch
    rm -rf "$dest"; mkdir -p "$dest"
    git -C "$dest" init -q
    git -C "$dest" remote add origin "$repo"
    git -C "$dest" fetch -q --depth 1 origin "$ref"
    git -C "$dest" checkout -q FETCH_HEAD
  }
  echo "versitygw source from $repo @ $(git -C "$dest" rev-parse --short HEAD) ($ref)"
fi
rm -rf "$dest/.git"
test -f "$dest/go.mod" || { echo "no go.mod under $dest" >&2; exit 1; }
test -d "$dest/backend/daos" || { echo "$ref has no backend/daos: wrong branch?" >&2; exit 1; }
