#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# Render /etc/daos/daos_server.yml from environment unless one is mounted.
# The operator will own this file later (ConfigMap per node); for Phase 0 the
# environment variables below are the contract.
set -euo pipefail
CFG=/etc/daos/daos_server.yml
if [ ! -s "$CFG" ]; then
  : "${DAOS_SYSTEM_NAME:=daos_server}"
  : "${DAOS_ACCESS_POINTS:?comma-separated MS replica hostnames (odd count)}"
  : "${DAOS_PROVIDER:=ofi+verbs;ofi_rxm}"
  : "${DAOS_FABRIC_IFACE:?host NIC name, differs per host (ens2 vs ens2np0)}"
  : "${DAOS_FABRIC_PORT:=31316}"
  : "${DAOS_BDEV_LIST:?comma-separated NVMe PCI addresses}"
  : "${DAOS_TARGETS:=8}"
  : "${DAOS_HELPERS:=2}"
  : "${DAOS_SCM_SIZE_GB:=32}"
  : "${DAOS_NR_HUGEPAGES:=8192}"
  : "${DAOS_ALLOW_INSECURE:=false}"
  : "${DAOS_PINNED_NUMA:=}"
  aps=$(echo "$DAOS_ACCESS_POINTS" | tr ',' '\n' | sed 's/^/  - /')
  bdevs=$(echo "$DAOS_BDEV_LIST" | tr ',' '\n' | sed 's/^/          - "/; s/$/"/')
  numa_line=""; [ -n "$DAOS_PINNED_NUMA" ] && numa_line="    pinned_numa_node: ${DAOS_PINNED_NUMA}"
  cat > "$CFG" <<YAML
name: ${DAOS_SYSTEM_NAME}
access_points:
${aps}
port: 10001
provider: ${DAOS_PROVIDER}
nr_hugepages: ${DAOS_NR_HUGEPAGES}
disable_vfio: false
control_log_file: /var/log/daos/daos_server.log
control_metadata:
  path: /var/daos/control_metadata
transport_config:
  allow_insecure: ${DAOS_ALLOW_INSECURE}
  client_cert_dir: /etc/daos/certs/clients
  ca_cert: /etc/daos/certs/daosCA.crt
  cert: /etc/daos/certs/server.crt
  key: /etc/daos/certs/server.key
engines:
  - targets: ${DAOS_TARGETS}
    nr_xs_helpers: ${DAOS_HELPERS}
    fabric_iface: ${DAOS_FABRIC_IFACE}
    fabric_iface_port: ${DAOS_FABRIC_PORT}
${numa_line}
    log_file: /var/log/daos/daos_engine.0.log
    storage:
      - class: ram
        scm_mount: /mnt/daos0
        scm_size: ${DAOS_SCM_SIZE_GB}
      - class: nvme
        bdev_list:
${bdevs}
        bdev_roles: [wal, meta, data]
YAML
  echo "rendered $CFG from environment"
fi
exec daos_server start -o "$CFG" "$@"
