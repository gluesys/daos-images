# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# vllm-lmcache-daos: vLLM + LMCache + the lmcache-daos connector on top of the
# stock DAOS 2.8 client. This is the serving image for the Kubernetes reference
# deployment (daos-operator #25): LMCache's remote backend is a DAOS container
# reached through libdaos/libdfs (ctypes), so the pod needs the daos_agent
# sidecar and nothing else -- no dfuse, no PV, no GDS.
#
# Built on daos-client (EL9) rather than on lmcache/vllm-openai (Ubuntu) so the
# DAOS client comes from the same RPMs every other image here uses; vLLM and
# LMCache are plain manylinux wheels and do not care about the distribution.
# The build context must hold the connector source at src/ --
# scripts/fetch-lmcache-daos.sh puts it there.
ARG IMAGE_NSP=daos
ARG IMAGE_TAG=dev
FROM ${IMAGE_NSP}/daos-client:${IMAGE_TAG}
ARG VLLM_VERSION=0.30.0
ARG LMCACHE_VERSION=0.5.5
ARG LMCACHE_DAOS_REF=unknown
# python3.12: vLLM wheels are cp38-abi3 but LMCache's are cp312
RUN dnf -y install python3.12 python3.12-pip python3.12-devel gcc-c++ git && dnf clean all \
 && python3.12 -m pip install --no-cache-dir --upgrade pip
# the two wheels together are ~7 GB (torch/cuda libs ride along); a single layer
RUN python3.12 -m pip install --no-cache-dir "vllm==${VLLM_VERSION}" "lmcache==${LMCACHE_VERSION}"
COPY src /opt/lmcache-daos
RUN python3.12 -m pip install --no-cache-dir /opt/lmcache-daos \
 && python3.12 -c "import vllm, lmcache, lmcache_daos; print('vllm', vllm.__version__, 'lmcache', lmcache.__version__, 'lmcache_daos', getattr(lmcache_daos, '__version__', '?'))" \
 && python3.12 -c "import lmcache.integration.vllm.lmcache_connector_v1" \
 && python3.12 -c "import lmcache_daos.connector"
LABEL org.opencontainers.image.title="vllm-lmcache-daos" \
      org.opencontainers.image.description="vLLM + LMCache with the DAOS remote connector, stock DAOS 2.8 client" \
      org.opencontainers.image.licenses="Apache-2.0" \
      io.gluesys.vllm="${VLLM_VERSION}" io.gluesys.lmcache="${LMCACHE_VERSION}" io.gluesys.lmcache-daos="${LMCACHE_DAOS_REF}"
# lmcache-daos: hashes must be stable across processes (README, "PYTHONHASHSEED=0")
ENV PYTHONHASHSEED=0 \
    DAOS_AGENT_DRPC_DIR=/var/run/daos_agent \
    HF_HOME=/data/hf_cache
ENTRYPOINT ["/usr/local/bin/python3.12", "-m", "vllm.entrypoints.openai.api_server"]
