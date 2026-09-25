<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 Gluesys Co., Ltd. -->

# daos-images

DAOS 2.8 컨테이너 이미지 4종(`daos-server`, `daos-agent`, `daos-client`, `daos-admin`)과
S3 게이트웨이 이미지(`versitygw-daos`), 에어갭 번들 스크립트.
`exastor/daos-operator` 와 `exastor/daos-csi` 가 소비한다.

이 저장소가 지키는 규칙(모든 exastor K8s 저장소 공통):
1. **CRD 가 유일한 관리 API** — 이미지는 설정을 env/ConfigMap 에서만 받는다.
2. **두 번째 SSoT 를 만들지 않는다** — 상태는 DAOS MS DB 와 메트릭에서 읽는다.
3. **파괴적 작업 자동화 금지** — `storage format`/wipe 는 엔트리포인트가 절대 실행하지 않는다.
4. **upstream-first** — 패치는 먼저 daos-stack 으로.

## 빌드
```bash
make all                 # base + 4 roles, 태그 = 2.8.0-YYYYMMDD
make admin IMAGE_TAG=dev # 하나만
make save                # 에어갭 tar + sha256 + load 스크립트
```

### versitygw-daos (S3 게이트웨이)
네이티브 DAOS 백엔드를 가진 Versity S3 게이트웨이다(버킷 1개 = 풀 안의 DFS 컨테이너 1개, libdfs 직결).
소스는 **다른 저장소**(`exastor/versitygw`, 기본 ref `feature/daos-backend`)라 4종과 빌드 주기가 다르고,
`daos-client` 를 다시 만들지 않는다.
```bash
make versitygw IMAGE_NSP=$REGISTRY IMAGE_TAG=2.8.0-20260914   # 발행된 client 위에 빌드
make versitygw VGW_SRC=~/src/Flexa/versitygw                  # 로컬 체크아웃으로
make push-versitygw IMAGE_TAG=2.8.0-20260923
```
`scripts/fetch-versitygw.sh` 가 소스를 빌드 컨텍스트(`images/versitygw/src`, git 미추적)로 가져오므로
자격증명이 이미지에 들어가지 않는다. 빌드는 Go 툴체인을 sha256 고정해 내려받고
`CGO_ENABLED=1 go build -tags daos` 로 `-ldfs -ldaos -lgurt -luuid` 를 링크한다.
쿠버네티스에서는 `daos-operator` 의 `S3Service` CRD 가 이 이미지를 띄운다(ADR-004).

### vllm-lmcache-daos (vLLM + LMCache + DAOS 커넥터)
daos-operator #25 참조 배포용 서빙 이미지. `daos-client` 위에 python3.12 와 **vLLM·LMCache wheel**, 그리고
`lmcache-daos` 커넥터(순수 파이썬, ctypes 로 libdaos/libdfs)를 얹는다. 파드는 daos_agent 소켓만 있으면 되고
dfuse·PV·GDS 는 필요 없다. Ubuntu 기반 `lmcache/vllm-openai` 대신 EL9 를 쓰는 이유는 DAOS 클라이언트를
다른 이미지와 같은 RPM 에서 가져오기 위해서다(wheel 은 배포판을 가리지 않는다).
```bash
make vllm-lmcache IMAGE_NSP=$REGISTRY IMAGE_TAG=2.8.0-20260914 VLLM_VERSION=0.30.0 LMCACHE_VERSION=0.5.5
make vllm-lmcache LMD_SRC=~/src/Flexa/lmcache-daos            # 로컬 체크아웃으로
```
`PYTHONHASHSEED=0`(lmcache-daos 요구)과 `DAOS_AGENT_DRPC_DIR` 이 기본 env 다. 첫 태그 `0.30.0-0.5.5-20260926`
(vllm 0.30.0 + lmcache 0.5.5 + lmcache-daos e40c1fa, torch cu13, sm_86 포함).
공식 배포는 RPM 만 존재하므로(packages.daos.io) 이미지는 v2.8 EL9 RPM 을 설치해 만든다.
GPU-direct 초안(`theodore/b_cufile`)은 이미지에 넣지 않는다.

## 레지스트리
`registry.gitlab.gluesys.com/exastor/daos-images/daos-{base,server,agent,client,admin}:<tag>`,
`.../versitygw-daos:<tag>`.
첫 push 2026-09-14, 태그 `2.8.0-20260914`. GitLab API 가 알려주는 prefix 에는 `:80` 이 붙어 있지만
실제 레지스트리는 443 TLS 로 동작하므로 호스트명만 쓴다.
```bash
make login GITLAB_TOKEN=<pat> GITLAB_USER=<user> DOCKER="sudo docker"
make push IMAGE_TAG=2.8.0-20260914 DOCKER="sudo docker"
```

## 실행 계약 (Phase 0)
서버는 `--privileged --network host` 와 hugepages/vfio/sysfs 마운트가 필요하다(ADR-002).
설정 파일이 마운트되지 않으면 엔트리포인트가 환경변수에서 YAML 을 렌더링한다:
`DAOS_MS_REPLICAS`(서버; agent 는 `DAOS_ACCESS_POINTS`), `DAOS_FABRIC_IFACE`, `DAOS_BDEV_LIST`(필수),
`DAOS_PROVIDER`, `DAOS_TARGETS`, `DAOS_SCM_SIZE_GB`, `DAOS_NR_HUGEPAGES`, `DAOS_ALLOW_INSECURE`.
Week-3 수동 기동 절차는 `compose/` 를 본다.

## SBOM
`make sbom` 이 syft 로 이미지별 SPDX JSON 을 `sbom/` 에 만든다(git 에는 넣지 않음). 산출물은 GitLab
Generic Package `daos-images-sbom/<tag>/` 에 올린다(첫 업로드 2026-09-14, 태그 2.8.0-20260914, 5개).
2.8 EL9 RPM 이 번들한 주요 버전: daos 2.8.0-6.el9, mercury 2.4.1-3, libfabric 2.3.1-3, daos-spdk 26.01-2, argobots 1.2-4.

## 아직 검증되지 않은 것
- 렌더링된 `daos_server.yml` 이 2.8 스키마와 정확히 맞는지 (실기동 로그로 확인)
- 인증서 생성/배포 — operator 의 Secret 이 맡는다
- 이미지 서명(cosign) — Phase 2

## 관련
ADR: `exastor/daos-operator/doc/adr/`. 사업·기술 배경: FlexA Hub 문서 `c82997c1-c66a-4728-ba21-24aeb2562535`.
