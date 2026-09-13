# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# daos-client: libdaos/libdfs/dfuse + daos CLI. Base for CSI node plugin,
# lmcache-daos and the NIXL plugin runtime. Talks to daos-agent via
# /var/run/daos_agent (mount from the agent container or host).
ARG IMAGE_NSP=daos
ARG IMAGE_TAG=dev
FROM ${IMAGE_NSP}/daos-base:${IMAGE_TAG}
ARG DAOS_VERSION=2.8.0
RUN dnf -y --allowerasing install daos-client-${DAOS_VERSION}* daos-devel-${DAOS_VERSION}* mercury-libfabric fuse3 python3 libuuid-devel \
 && dnf clean all && mkdir -p /var/run/daos_agent
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
