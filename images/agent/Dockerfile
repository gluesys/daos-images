# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# daos-agent: per-node agent that clients talk to over a UNIX socket.
ARG IMAGE_NSP=daos
ARG IMAGE_TAG=dev
FROM ${IMAGE_NSP}/daos-base:${IMAGE_TAG}
ARG DAOS_VERSION=2.8.0
RUN dnf -y --allowerasing install daos-client-${DAOS_VERSION}* mercury-libfabric \
 && dnf clean all && mkdir -p /var/run/daos_agent /etc/daos/certs /var/log/daos
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
VOLUME ["/var/run/daos_agent", "/etc/daos"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
