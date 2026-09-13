<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 Gluesys Co., Ltd. -->

# daos-images

DAOS 2.8 컨테이너 이미지 4종(`daos-server`, `daos-agent`, `daos-client`, `daos-admin`)과
에어갭 번들 스크립트. `exastor/daos-operator` 와 `exastor/daos-csi` 가 소비한다.

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
공식 배포는 RPM 만 존재하므로(packages.daos.io) 이미지는 v2.8 EL9 RPM 을 설치해 만든다.
GPU-direct 초안(`theodore/b_cufile`)은 이미지에 넣지 않는다.

## 실행 계약 (Phase 0)
서버는 `--privileged --network host` 와 hugepages/vfio/sysfs 마운트가 필요하다(ADR-002).
설정 파일이 마운트되지 않으면 엔트리포인트가 환경변수에서 YAML 을 렌더링한다:
`DAOS_ACCESS_POINTS`, `DAOS_FABRIC_IFACE`, `DAOS_BDEV_LIST`(필수),
`DAOS_PROVIDER`, `DAOS_TARGETS`, `DAOS_SCM_SIZE_GB`, `DAOS_NR_HUGEPAGES`, `DAOS_ALLOW_INSECURE`.
Week-3 수동 기동 절차는 `compose/` 를 본다.

## 아직 검증되지 않은 것
- 렌더링된 `daos_server.yml` 이 2.8 스키마와 정확히 맞는지 (`daos_server config` 검증 필요)
- 인증서 생성/배포 — operator 의 Secret 이 맡는다
- SBOM(syft)·서명(cosign) — Phase 2

## 관련
ADR: `exastor/daos-operator/doc/adr/`. 사업·기술 배경: FlexA Hub 문서 `c82997c1-c66a-4728-ba21-24aeb2562535`.
