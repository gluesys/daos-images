#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# Bundle images for an air-gapped site: one tarball + sha256 + load script.
set -euo pipefail
NSP=$1; TAG=$2; shift 2
OUT=daos-images-${TAG}.tar
imgs=(); for r in "$@"; do imgs+=("${NSP}/daos-${r}:${TAG}"); done
docker save -o "$OUT" "${imgs[@]}"
sha256sum "$OUT" > "$OUT.sha256"
cat > "load-${TAG}.sh" <<LOAD
#!/bin/bash
set -e; sha256sum -c "$OUT.sha256"; docker load -i "$OUT"
LOAD
chmod +x "load-${TAG}.sh"; echo "wrote $OUT $OUT.sha256 load-${TAG}.sh"
