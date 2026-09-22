# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# daos-server: the storage engine. Needs --privileged, host network, hugepages
# and /dev/vfio from the host (see ADR-002 in exastor/daos-operator).
ARG IMAGE_NSP=daos
ARG IMAGE_TAG=dev
FROM ${IMAGE_NSP}/daos-base:${IMAGE_TAG}
ARG DAOS_VERSION=2.8.0
# --allowerasing: DAOS pins its own mercury / libisa-l_crypto builds.
# libaio: the file and kdev storage classes go through SPDK's AIO backend, and
# daos_engine will not even load without it (found on exaci4-2, 2026-09-22).
RUN dnf -y --allowerasing install daos-server-${DAOS_VERSION}* mercury-libfabric pciutils numactl libaio \
 && dnf clean all && mkdir -p /var/daos /var/log/daos /etc/daos/certs /mnt/daos0 /mnt/daos1 /var/run/daos_server
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh
VOLUME ["/var/daos", "/etc/daos", "/var/log/daos"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
