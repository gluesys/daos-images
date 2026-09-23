# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# versitygw-daos: the Versity S3 gateway with the Gluesys native DAOS backend
# (exastor/versitygw, `make build-daos-native`). One S3 bucket = one DFS
# container in a DAOS pool; the gateway links libdfs directly, so it needs the
# DAOS client runtime but no dfuse and no mount.
#
# The build context must hold the gateway source at src/ -- scripts/fetch-versitygw.sh
# puts it there, so no credentials ever reach the image.
ARG IMAGE_NSP=daos
ARG IMAGE_TAG=dev
FROM ${IMAGE_NSP}/daos-client:${IMAGE_TAG} AS build
# daos-devel (daos.h, daos_fs.h) comes with daos-client; libuuid-devel is
# installed here rather than assumed, because the cgo backend includes
# <uuid/uuid.h> and links -ldfs -ldaos -lgurt -luuid
ARG GO_VERSION=1.26.8
ARG GO_SHA256=d0f743b33e8d8945e6b1f432edd15785c70507121d6e2a723b21285eddf8b57b
RUN dnf -y install gcc make git tar gzip ca-certificates libuuid-devel && dnf clean all
RUN curl -fsSL -o /tmp/go.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
 && echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum -c - \
 && tar -C /usr/local -xzf /tmp/go.tar.gz && rm -f /tmp/go.tar.gz
ENV PATH=/usr/local/go/bin:$PATH GOFLAGS=-mod=mod GOTOOLCHAIN=local
COPY src /src
WORKDIR /src
ARG VGW_VERSION=dev
ARG VGW_BUILD=none
# same flags as the fork's `make build-daos-native`
RUN CGO_ENABLED=1 go build -tags daos \
      -ldflags "-X=main.Version=${VGW_VERSION} -X=main.Build=${VGW_BUILD} -X=main.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      -o /versitygw ./cmd/versitygw

FROM ${IMAGE_NSP}/daos-client:${IMAGE_TAG}
ARG VGW_VERSION=dev
LABEL org.opencontainers.image.title="versitygw-daos" \
      org.opencontainers.image.description="Versity S3 gateway with the native DAOS backend" \
      org.opencontainers.image.version="${VGW_VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0"
COPY --from=build /versitygw /usr/local/bin/versitygw
RUN chmod 0755 /usr/local/bin/versitygw \
 && mkdir -p /var/lib/versitygw/iam \
 && /usr/local/bin/versitygw --version
# No entrypoint script: the gateway takes its whole configuration from flags and
# the environment, and the operator (S3Service) supplies both.
ENTRYPOINT ["/usr/local/bin/versitygw"]
CMD ["--help"]
