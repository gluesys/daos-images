#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
set -euo pipefail
# Any explicit command (bash, sh, daos_* subcommands) bypasses the daemon path.
case "${1:-}" in ""|-*) ;; *) exec "$@" ;; esac
CFG=/etc/daos/daos_agent.yml
if [ ! -s "$CFG" ]; then
  : "${DAOS_SYSTEM_NAME:=daos_server}"
  : "${DAOS_ACCESS_POINTS:?comma-separated MS replica hostnames}"
  : "${DAOS_ALLOW_INSECURE:=false}"
  aps=$(echo "$DAOS_ACCESS_POINTS" | tr ',' '\n' | sed 's/^/  - /')
  # fabric_ifaces.domain needs the port suffix (mlx5_0:1) for verbs; left to
  # the operator/ConfigMap because it is per host.
  cat > "$CFG" <<YAML
name: ${DAOS_SYSTEM_NAME}
access_points:
${aps}
port: 10001
runtime_dir: /var/run/daos_agent
log_file: /var/log/daos/daos_agent.log
transport_config:
  allow_insecure: ${DAOS_ALLOW_INSECURE}
  ca_cert: /etc/daos/certs/daosCA.crt
  cert: /etc/daos/certs/agent.crt
  key: /etc/daos/certs/agent.key
YAML
  echo "rendered $CFG from environment"
fi
exec daos_agent -o "$CFG" "$@"
