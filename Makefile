# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Gluesys Co., Ltd.
include VERSION
IMAGE_NSP ?= daos
IMAGE_TAG ?= $(DAOS_VERSION)-$(shell date +%Y%m%d)
DOCKER    ?= docker
ROLES      = server agent client admin

.PHONY: all base $(ROLES) sbom save clean print-tag
all: base $(ROLES)
print-tag: ; @echo $(IMAGE_TAG)
base:
	$(DOCKER) build -f images/Dockerfile.base --build-arg BASE_IMAGE=$(BASE_IMAGE) \
	  --build-arg DAOS_REPO_URL=$(DAOS_REPO_URL) -t $(IMAGE_NSP)/daos-base:$(IMAGE_TAG) images
$(ROLES): base
	$(DOCKER) build -f images/$@/Dockerfile --build-arg IMAGE_NSP=$(IMAGE_NSP) --build-arg IMAGE_TAG=$(IMAGE_TAG) \
	  --build-arg DAOS_VERSION=$(DAOS_VERSION) -t $(IMAGE_NSP)/daos-$@:$(IMAGE_TAG) images/$@
sbom: ## requires syft
	@for r in $(ROLES); do syft $(IMAGE_NSP)/daos-$$r:$(IMAGE_TAG) -o spdx-json > sbom-daos-$$r-$(IMAGE_TAG).spdx.json; done
save: ## air-gap bundle
	scripts/save-airgap.sh $(IMAGE_NSP) $(IMAGE_TAG) $(ROLES)
clean:
	-$(DOCKER) image rm $(foreach r,base $(ROLES),$(IMAGE_NSP)/daos-$(r):$(IMAGE_TAG))
