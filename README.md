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
make vllm-lmcache IMAGE_NSP=$REGISTRY IMAGE_TAG=2.8.0-20261006-g41c3647d VLLM_VERSION=0.30.0 LMCACHE_VERSION=0.5.5
make vllm-lmcache IMAGE_NSP=$REGISTRY IMAGE_TAG=2.8.0-20261006-g41c3647d \
  LMD_SRC=~/src/Flexa/lmcache-daos LMD_SRC_REF=origin/main      # 로컬 체크아웃의 특정 ref 로
docker tag $REGISTRY/vllm-lmcache-daos:2.8.0-20261006-g41c3647d $REGISTRY/vllm-lmcache-daos:0.30.0-0.5.5-$(date +%Y%m%d)
make push-vllm-lmcache IMAGE_NSP=$REGISTRY IMAGE_TAG=0.30.0-0.5.5-$(date +%Y%m%d)
```
`IMAGE_TAG` 는 베이스(`daos-client`) 태그이자 결과 이미지의 첫 태그다. 배포용 태그
`0.30.0-0.5.5-YYYYMMDD` 는 위처럼 다시 붙인다. **베이스는 libfabric 을 DAOS 저장소 1.22.0 으로 고정한
client(41c3647 이후, `2.8.0-20261006-g41c3647d`)를 쓴다.** 그 전 베이스(`2.8.0-20260914`)는 Rocky AppStream
의 libfabric 2.3.1 이 들어 있어, 다른 스레드가 I/O 중일 때 이벤트 큐를 만들면 verbs 공급자에서 segfault 가
난다(lmcache-daos rank 가드·nixl-daos 처럼 이벤트 큐를 여럿 쓰는 경로가 해당).

`PYTHONHASHSEED=0`(lmcache-daos 요구)과 `DAOS_AGENT_DRPC_DIR` 이 기본 env 다.

| 태그 | 베이스 / libfabric | lmcache-daos | 비고 |
|---|---|---|---|
| `0.30.0-0.5.5-20260926` | 2.8.0-20260914 / 2.3.1 | e40c1fa | 첫 태그(torch cu13, sm_86 포함) |
| `0.30.0-0.5.5-20260927` | 2.8.0-20260914 / 2.3.1 | e40c1fa | `which` 추가(flashinfer CUDA 경로 탐색) |
| `0.30.0-0.5.5-20261020` | 2.8.0-20260914 / **2.3.1** | 1111741 | plugin 경로 대상 지정·MP `guard_oclass`. libfabric 때문에 쓰지 않는다 |
| `0.30.0-0.5.5-20261021` | 2.8.0-20261006-g41c3647d / **1.22.0-5** | 1111741 | libfabric 고정 |
| `0.30.0-0.5.5-20261021.2` | 2.8.0-20261006-g41c3647d / **1.22.0-5** | d76c6d5 | rank 가드 장애 중 재배치(`DAOS_RANK_GUARD_RELOCATE`) 포함. 같은 날 두 번째 빌드라 `.2`. **LMCache KV 절반 복사 버그 있음(아래)** |
| `0.30.0-0.5.5-20261025` | 2.8.0-20261006-g41c3647d / **1.22.0-5** | d76c6d5 | LMCache fused K/V 패치(`patches/lmcache-0.5.5-fused-kv.patch`) |
| `0.30.0-0.5.5-20261025.2` | 2.8.0-20261006-g41c3647d / **1.22.0-5** | 313e5d7 | fused K/V 패치 + 재배치 예산·공간 기준 축출(S3-FIFO 기본)·CacheGen 저장 수정 |
| `0.30.0-0.5.5-20261028` | 2.8.0-20261006-g41c3647d / **1.22.0-5** | c4dcae1 | 현재. 20261025.2 + 재사용 통계(`DAOS_REUSE_STATS`, tiering 판단용). daos-operator 차트 예시가 가리키는 태그 |

**LMCache 0.5.5 패치.** vLLM 0.30 은 레이어마다 K·V 를 한 축에 붙인 `[블록, 블록 크기, head, 2×head_dim]`
배치를 쓴다. LMCache 0.5.5 의 `VLLMPagedMemGPUConnectorV2` 는 이 배치를 인식하지만 메모리 객체를
`[2, 레이어, 토큰, head×head_dim]` 로 만든다. 복사 커널은 첫 면에 토큰당 두 배 값을 채우다 토큰 절반에서
멈춘다. 그래서 256 토큰 청크마다 앞 128 토큰만 저장·복원되고, 나머지 토큰에는 GPU 블록에 남아 있던 다른
요청의 KV 가 쓰인다. 패치는 fused 배치일 때 커널에 넘기는 객체를 `[1, 레이어, 토큰, 2×head×head_dim]` 로 본다.
레인 A needle 시험(문서 40개, 같은 질문 두 번)에서 cache hit 정답률이 55 % → 97.5 %(LMCache 없음과 같음)가
되고, hit TTFT 는 그대로다. Dockerfile 은 `patches/lmcache-<LMCACHE_VERSION>-*.patch` 만 적용한다.
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
2.8 EL9 RPM 이 번들한 주요 버전: daos 2.8.0-6.el9, mercury 2.4.1-3, libfabric 1.22.0-5(DAOS 저장소, Rocky AppStream 의 2.3.1 은 제외 — images/Dockerfile.base 주석), daos-spdk 26.01-2, argobots 1.2-4.

## 아직 검증되지 않은 것
- 렌더링된 `daos_server.yml` 이 2.8 스키마와 정확히 맞는지 (실기동 로그로 확인)
- 인증서 생성/배포 — operator 의 Secret 이 맡는다
- 이미지 서명(cosign) — Phase 2

## 관련
ADR: `exastor/daos-operator/doc/adr/`. 사업·기술 배경: FlexA Hub 문서 `c82997c1-c66a-4728-ba21-24aeb2562535`.
