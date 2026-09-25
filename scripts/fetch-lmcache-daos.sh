#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# Put the lmcache-daos source into images/vllm-lmcache-daos/src for the image
# build (git is public on GitHub; a local checkout works too).
#   scripts/fetch-lmcache-daos.sh [ref]                      # clone gluesys/lmcache-daos at <ref>
#   LMD_SRC=~/src/Flexa/lmcache-daos scripts/fetch-lmcache-daos.sh   # local tree (HEAD)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$here/images/vllm-lmcache-daos/src"
ref="${1:-${LMD_REF:-main}}"
repo="${LMD_REPO:-https://github.com/gluesys/lmcache-daos.git}"
rm -rf "$dest"; mkdir -p "$dest"
if [ -n "${LMD_SRC:-}" ]; then
  test -d "$LMD_SRC/.git" || { echo "LMD_SRC=$LMD_SRC is not a git checkout" >&2; exit 1; }
  git -C "$LMD_SRC" archive --format=tar "${LMD_SRC_REF:-HEAD}" | tar -x -C "$dest"
  echo "lmcache-daos source from $LMD_SRC @ $(git -C "$LMD_SRC" rev-parse --short "${LMD_SRC_REF:-HEAD}")"
else
  git clone -q --depth 1 --branch "$ref" "$repo" "$dest"
  echo "lmcache-daos source from $repo @ $(git -C "$dest" rev-parse --short HEAD) ($ref)"
  rm -rf "$dest/.git"
fi
test -f "$dest/pyproject.toml" || { echo "no pyproject.toml under $dest" >&2; exit 1; }
