# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
include VERSION
IMAGE_NSP ?= daos
# GitLab project registry. The API reports the prefix with :80, but the registry
# serves TLS on 443 and docker login/push work against the bare hostname.
REGISTRY  ?= registry.gitlab.gluesys.com/exastor/daos-images
IMAGE_TAG ?= $(DAOS_VERSION)-$(shell date +%Y%m%d)
DOCKER    ?= docker
GITLAB_USER ?= $(USER)
ROLES      = server agent client admin
# versitygw is built from a second repository (exastor/versitygw), so it is not
# part of ROLES: `make versitygw` fetches that source first.
VGW_REF   ?= feature/daos-backend

.PHONY: all base $(ROLES) versitygw sbom sbom-upload save clean print-tag login push push-versitygw validate-config
all: base $(ROLES)
print-tag: ; @echo $(IMAGE_TAG)
base:
	$(DOCKER) build -f images/Dockerfile.base --build-arg BASE_IMAGE=$(BASE_IMAGE) \
	  --build-arg DAOS_REPO_URL=$(DAOS_REPO_URL) -t $(IMAGE_NSP)/daos-base:$(IMAGE_TAG) images
$(ROLES): base
	$(DOCKER) build -f images/$@/Dockerfile --build-arg IMAGE_NSP=$(IMAGE_NSP) --build-arg IMAGE_TAG=$(IMAGE_TAG) \
	  --build-arg DAOS_VERSION=$(DAOS_VERSION) -t $(IMAGE_NSP)/daos-$@:$(IMAGE_TAG) images/$@
## versitygw-daos: S3 gateway with the native DAOS backend (daos-operator S3Service).
## Source comes from exastor/versitygw; VGW_SRC=<path> builds a local checkout instead.
## The daos-client base is not rebuilt here (this image follows the gateway's own
## cadence): build it with `make client`, or point at a published one, e.g.
##   make versitygw IMAGE_NSP=$(REGISTRY) IMAGE_TAG=2.8.0-20260914
versitygw:
	scripts/fetch-versitygw.sh $(VGW_REF)
	$(DOCKER) build -f images/versitygw/Dockerfile --build-arg IMAGE_NSP=$(IMAGE_NSP) --build-arg IMAGE_TAG=$(IMAGE_TAG) \
	  --build-arg VGW_VERSION=$(IMAGE_TAG) -t $(IMAGE_NSP)/versitygw-daos:$(IMAGE_TAG) images/versitygw
push-versitygw:
	$(DOCKER) tag $(IMAGE_NSP)/versitygw-daos:$(IMAGE_TAG) $(REGISTRY)/versitygw-daos:$(IMAGE_TAG)
	$(DOCKER) push $(REGISTRY)/versitygw-daos:$(IMAGE_TAG)

SYFT ?= syft
sbom: ## requires syft (reads the docker socket; use SYFT="sudo syft" if docker needs root)
	@mkdir -p sbom; for r in base $(ROLES); do $(SYFT) $(IMAGE_NSP)/daos-$$r:$(IMAGE_TAG) -o spdx-json -q > sbom/daos-$$r-$(IMAGE_TAG).spdx.json; done; ls -la sbom/
sbom-upload: ## GitLab generic package daos-images-sbom/$(IMAGE_TAG)/ (GITLAB_TOKEN, GITLAB_PROJECT_ID)
	@for f in sbom/*-$(IMAGE_TAG).spdx.json; do curl -s -H "PRIVATE-TOKEN: $(GITLAB_TOKEN)" --upload-file $$f \
	  "https://gitlab.gluesys.com/api/v4/projects/$(GITLAB_PROJECT_ID)/packages/generic/daos-images-sbom/$(IMAGE_TAG)/$$(basename $$f)"; echo; done
save: ## air-gap bundle
	scripts/save-airgap.sh $(IMAGE_NSP) $(IMAGE_TAG) $(ROLES)
login: ## docker login with a GitLab PAT (read_registry/write_registry or api scope)
	@test -n "$(GITLAB_TOKEN)" || { echo 'GITLAB_TOKEN=<pat> required'; exit 1; }
	@echo "$(GITLAB_TOKEN)" | $(DOCKER) login $(firstword $(subst /, ,$(REGISTRY))) -u $(GITLAB_USER) --password-stdin
push: ## retag daos/<role>:$(IMAGE_TAG) -> $(REGISTRY)/daos-<role>:$(IMAGE_TAG) and push
	@for r in base $(ROLES); do \
	  $(DOCKER) tag $(IMAGE_NSP)/daos-$$r:$(IMAGE_TAG) $(REGISTRY)/daos-$$r:$(IMAGE_TAG) && \
	  $(DOCKER) push $(REGISTRY)/daos-$$r:$(IMAGE_TAG); done
clean:
	-$(DOCKER) image rm $(foreach r,base $(ROLES),$(IMAGE_NSP)/daos-$(r):$(IMAGE_TAG))

## Validate DAOS configuration files against the real 2.8 binaries (no hardware
## needed; see scripts/validate-config.sh for how far it gets).
##   make validate-config KIND=server FILE=/path/daos_server.yml
KIND ?= server
FILE ?=
validate-config:
	@test -n "$(FILE)" || { echo "FILE=<config> is required"; exit 2; }
	DOCKER="$(DOCKER)" IMAGE_NSP="$(IMAGE_NSP)" IMAGE_TAG="$(IMAGE_TAG)" scripts/validate-config.sh $(KIND) $(FILE)
