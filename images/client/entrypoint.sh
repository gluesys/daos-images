#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# If DAOS_POOL and DAOS_CONT are set, mount them with dfuse at DAOS_MOUNT and
# keep the container alive; otherwise run the given command.
set -euo pipefail
if [ -n "${DAOS_POOL:-}" ] && [ -n "${DAOS_CONT:-}" ]; then
  : "${DAOS_MOUNT:=/mnt/daos}"
  mkdir -p "$DAOS_MOUNT"
  dfuse --pool "$DAOS_POOL" --container "$DAOS_CONT" --mountpoint "$DAOS_MOUNT" --foreground &
  DF=$!
  trap 'fusermount3 -u "$DAOS_MOUNT" || true; kill $DF || true' TERM INT
  wait $DF
else
  exec "$@"
fi
