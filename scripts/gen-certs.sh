#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# Generate DAOS transport certificates for a NON-Kubernetes bring-up (the
# compose runbook). It runs the upstream generator that ships inside the image
# (/usr/lib64/daos/certgen/gen_certificates.sh) and then lays the files out the
# way each role expects, with the modes DAOS enforces:
#
#   <out>/server/{daosCA.crt,server.crt,server.key,clients/{agent,admin}.crt}
#   <out>/agent/{daosCA.crt,agent.crt,agent.key}
#   <out>/admin/{daosCA.crt,admin.crt,admin.key}
#
# On Kubernetes you do NOT need this: the operator generates the same material
# into Secret <system>-certs and rotates it (exastor/daos-operator #16, #19).
#
#   scripts/gen-certs.sh [out-dir]          # default ./certs
set -euo pipefail
out="${1:-certs}"
: "${IMAGE_NSP:=registry.gitlab.gluesys.com/exastor/daos-images}"
: "${IMAGE_TAG:=2.8.0-20260914}"
: "${DOCKER:=docker}"

[ -e "$out" ] && { echo "$out already exists; move it away first (certificates are not overwritten)" >&2; exit 1; }
mkdir -p "$out"
abs="$(realpath "$out")"

$DOCKER run --rm -v "$abs":/out "$IMAGE_NSP/daos-server:$IMAGE_TAG" \
  bash -c '/usr/lib64/daos/certgen/gen_certificates.sh /out >/dev/null && chmod -R a+rX,u+rw /out/daosCA'

ca="$abs/daosCA/certs"
[ -f "$ca/daosCA.crt" ] || { echo "generator produced no CA in $ca" >&2; exit 1; }

install -d -m 0755 "$abs/server/clients" "$abs/agent" "$abs/admin"
install -m 0644 "$ca/daosCA.crt" "$abs/server/daosCA.crt"
install -m 0644 "$ca/server.crt" "$abs/server/server.crt"
install -m 0400 "$ca/server.key" "$abs/server/server.key"
install -m 0644 "$ca/agent.crt"  "$abs/server/clients/agent.crt"
install -m 0644 "$ca/admin.crt"  "$abs/server/clients/admin.crt"
install -m 0644 "$ca/daosCA.crt" "$abs/agent/daosCA.crt"
install -m 0644 "$ca/agent.crt"  "$abs/agent/agent.crt"
install -m 0400 "$ca/agent.key"  "$abs/agent/agent.key"
install -m 0644 "$ca/daosCA.crt" "$abs/admin/daosCA.crt"
install -m 0644 "$ca/admin.crt"  "$abs/admin/admin.crt"
install -m 0400 "$ca/admin.key"  "$abs/admin/admin.key"

cat <<TXT
certificates written to $abs

  server : $abs/server   -> mount at /etc/daos/certs in daos-server
  agent  : $abs/agent    -> mount at /etc/daos/certs in daos-agent and clients
  admin  : $abs/admin    -> mount at /etc/daos/certs in daos-admin (dmg)

The CA private key stays in $abs/daosCA/private -- keep it out of the images and
off shared hosts. Set DAOS_ALLOW_INSECURE=false in the compose .env once mounted.
TXT
