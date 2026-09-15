#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
#
# Validate a DAOS configuration file against the real 2.8 binaries, without
# starting anything. The control plane parses its YAML with UnmarshalStrict and
# then runs Validate(), so a bad key or an impossible engine layout fails before
# any hardware is touched; this script runs the binary, lets it get as far as
# hardware, and only looks at whether the configuration itself was accepted.
#
# How far it gets on a machine without DAOS hardware: the YAML is parsed with
# UnmarshalStrict against the real 2.8 structs (so a wrong or renamed key fails),
# then the fabric interface and host memory are checked. Engine/bdev semantics
# beyond that need a host with the NIC and RAM in the file -- that is the test
# bed bring-up, not this script.
#
#   scripts/validate-config.sh server /path/daos_server.yml
#   scripts/validate-config.sh agent  /path/daos_agent.yml
#   scripts/validate-config.sh control /path/daos_control.yml
#
# Env: IMAGE_NSP, IMAGE_TAG (defaults to the registry images), DOCKER, TIMEOUT.
set -euo pipefail

kind="${1:?server|agent|control}"
file="${2:?path to the configuration file}"
: "${IMAGE_NSP:=registry.gitlab.gluesys.com/exastor/daos-images}"
: "${IMAGE_TAG:=2.8.0-20260914}"
: "${DOCKER:=docker}"
: "${TIMEOUT:=40}"
[ -f "$file" ] || { echo "no such file: $file" >&2; exit 2; }

opts=()
case "$kind" in
  # daos_server spawns daos_server_helper, which reads /proc/<ppid>/exe; without
  # privileges that fails before the config is even loaded. Nothing from the host
  # is mounted, so this container still cannot touch real storage.
  server)  image="$IMAGE_NSP/daos-server:$IMAGE_TAG";  dest=/etc/daos/daos_server.yml;  cmd=(daos_server start -o /etc/daos/daos_server.yml); opts=(--privileged) ;;
  agent)   image="$IMAGE_NSP/daos-agent:$IMAGE_TAG";   dest=/etc/daos/daos_agent.yml;   cmd=(daos_agent -o /etc/daos/daos_agent.yml) ;;
  # `dmg version` does not read the config at all, so use a command that does.
  # A bad file fails in under a second ("failed to load control configuration");
  # a good one reaches the network and is killed by the timeout. Point the
  # hostlist at TEST-NET (RFC 5737) so nothing real is contacted.
  control) image="$IMAGE_NSP/daos-admin:$IMAGE_TAG";   dest=/etc/daos/daos_control.yml; cmd=(dmg -o /etc/daos/daos_control.yml -j system query); : "${CONTROL_TIMEOUT:=12}"; TIMEOUT="$CONTROL_TIMEOUT" ;;
  *) echo "kind must be server, agent or control" >&2; exit 2 ;;
esac

out=$($DOCKER run --rm "${opts[@]}" --entrypoint timeout -v "$(realpath "$file")":"$dest":ro "$image" \
      "$TIMEOUT" "${cmd[@]}" 2>&1 || true)

# Anything that means "the configuration itself is wrong".
bad=$(printf '%s\n' "$out" | grep -iE \
  'failed to load config|unmarshal errors|field .* not found|cannot unmarshal|invalid configuration|FaultBadConfig|ERROR: *serverconfig|config validation|unknown field|failed to read config|invalid parameters' || true)
if [ -n "$bad" ]; then
  echo "INVALID  $kind  $file"
  printf '%s\n' "$bad" | sed 's/^/    /'
  exit 1
fi

if [ "$kind" = control ]; then
  # no configuration complaint within the timeout means dmg accepted the file
  echo "OK       $kind  $file"
  exit 0
fi

# Proof that the binary got past configuration into hardware/network work.
case "$kind" in
  server)  ok='config loaded from|Checking DAOS I/O Engine|DAOS Control Server' ;;
  # the agent logs its config before anything else fails (certificates, fabric, socket)
  agent)   ok='DAOS Agent|listening on|fabric|attach info|Failed to bind|no ifaces|Certificate Data|certificates are enabled' ;;
  control) ok='"response"|"error"|"version"|unable to contact|refused the connection' ;;
esac
if printf '%s\n' "$out" | grep -qiE "$ok"; then
  echo "OK       $kind  $file"
  exit 0
fi
echo "UNKNOWN  $kind  $file  (binary produced no configuration evidence)"
printf '%s\n' "$out" | tail -5 | sed 's/^/    /'
exit 1
