#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
set -euo pipefail
CFG=/etc/daos/daos_control.yml
# The RPM may ship a fully commented example; render unless an uncommented hostlist: exists.
if ! grep -qE "^hostlist:" "$CFG" 2>/dev/null; then
  : "${DAOS_SYSTEM_NAME:=daos_server}"
  : "${DAOS_HOSTLIST:?comma-separated server hostnames}"
  : "${DAOS_ALLOW_INSECURE:=false}"
  hl=$(echo "$DAOS_HOSTLIST" | tr ',' '\n' | sed 's/^/  - /')
  cat > "$CFG" <<YAML
name: ${DAOS_SYSTEM_NAME}
hostlist:
${hl}
port: 10001
transport_config:
  allow_insecure: ${DAOS_ALLOW_INSECURE}
  ca_cert: /etc/daos/certs/daosCA.crt
  cert: /etc/daos/certs/admin.crt
  key: /etc/daos/certs/admin.key
YAML
fi
if [ "${1:-}" = "dmg" ]; then shift; exec dmg -o "$CFG" "$@"; fi
exec "$@"
