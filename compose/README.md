<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 Gluesys Co., Ltd. -->

# Week 3 — 컨테이너로 DAOS 수동 기동 (Phase 0 종료 기준)

테스트베드 2호스트(daos_ci 34.21/22 또는 ExaCI5-4 .41/.42)에서 수행한다. 호스트가 2대라
관리 서비스 복제본은 1개(비 HA)이며 이 한계를 결과 문서에 적는다.

## 0. 시작 전 규칙
- `daos_server` 재시작과 `dmg storage format` 은 **테스트베드 소유자 승인 후**에만 (SPDK wedge → 풀 파기 전례).
- 듀얼포트 섀시: 두 호스트가 같은 물리 드라이브를 잡지 않는지 `lspci -vv | grep -A2 'Device Serial'` 의 DSN 으로 먼저 확인 (2026-09-03 손상 사건 원인).
- NIC 이름은 호스트별로 다르다(cell1 `ens2`, cell2 `ens2np0`). `.env` 를 호스트 간 복사하지 않는다.

## 1. 이미지 반입
```bash
make all IMAGE_TAG=2.8.0-$(date +%Y%m%d) DOCKER="sudo docker"   # 빌드 호스트
make save IMAGE_TAG=...                                          # 에어갭 tar
scp daos-images-*.tar* load-*.sh cell1:/root/ ; ssh cell1 ./load-*.sh
```

## 2. 호스트 준비 (노드마다, operator 의 DaemonSet 이 할 일)
```bash
sysctl -w vm.nr_hugepages=8192
modprobe vfio-pci
# 대상 NVMe 를 VFIO 로 바인딩 — 소유자 승인 후. daos-server 이미지 안의 도구를 쓴다:
docker run --rm --privileged --network host --pid host -v /dev:/dev -v /sys:/sys \
  daos/daos-server:<tag> daos_server nvme prepare
mkdir -p /var/daos /etc/daos/certs /var/log/daos /var/run/daos_agent
```

## 3. 기동
```bash
cp compose/testbed-2node.env.example compose/.env && vi compose/.env   # 호스트별 값
docker compose -f compose/docker-compose.yml up -d daos-server
docker logs -f daos-server            # "DAOS I/O Engine ... started" 까지
```
드라이런: `docker run --rm -e DAOS_RENDER_ONLY=1 --env-file compose/.env daos/daos-server:<tag>`.

## 4. 포맷·풀·컨테이너 (사람이 직접)
```bash
A="docker run --rm --network host -e DAOS_HOSTLIST=cell1 -e DAOS_ALLOW_INSECURE=true daos/daos-admin:<tag> dmg"
$A storage scan
$A storage format                      # ★ 파괴적. 승인된 장치만.
$A system query -v                     # 전 rank Joined
$A pool create --size 1T p0 --properties rd_fac:1
docker compose -f compose/docker-compose.yml up -d daos-agent
C="docker run --rm --network host -v /var/run/daos_agent:/var/run/daos_agent daos/daos-client:<tag>"
$C daos cont create p0 c0 --type POSIX --file-oclass RP_2GX --chunk-size 4194304
```

## 5. 수용 기준 (모두 스크립트·로그로 남길 것)
| # | 확인 | 방법 |
|---|---|---|
| 1 | 전 rank Joined | `dmg system query -v` |
| 2 | dfuse 마운트 + 왕복 | `docker run ... -e DAOS_POOL=p0 -e DAOS_CONT=c0 --device /dev/fuse --cap-add SYS_ADMIN daos-client`; lmcache-daos `tests/test_dfs_roundtrip.py` |
| 3 | 서버 컨테이너 재시작 후 풀 생존 | `docker compose restart daos-server` → `dmg pool list` (superblock 은 `/var/daos` hostPath) |
| 4 | 다른 팀원이 문서만으로 다른 노드에서 재현 | 이 문서 |

## 6. 알려진 미확인
- 렌더링된 yml 의 2.8 스키마 정합(기동 로그로 확인). `bdev_roles: [wal, meta, data]` 는 MD-on-SSD 단일 티어 가정.
- 인증서 없이 `allow_insecure: true` 로만 시험한다. 인증서는 operator Secret 이 맡는다.
