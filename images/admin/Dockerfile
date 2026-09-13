# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# daos-admin: dmg. Runs as a Job / kubectl-exec target, never as a daemon.
ARG IMAGE_NSP=daos
ARG IMAGE_TAG=dev
FROM ${IMAGE_NSP}/daos-base:${IMAGE_TAG}
ARG DAOS_VERSION=2.8.0
RUN dnf -y --allowerasing install daos-admin-${DAOS_VERSION}* && dnf clean all && mkdir -p /etc/daos/certs
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["dmg", "system", "query", "-v"]
