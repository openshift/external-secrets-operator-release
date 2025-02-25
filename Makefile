## local variables.
external_secrets_submodule_dir = external-secrets
external_secrets_operator_submodule_dir = external-secrets-operator
external_secrets_containerfile_name = Containerfile.external_secrets
commit_sha = $(strip $(shell git rev-parse HEAD))
source_url = $(strip $(shell git remote get-url origin))
release_version = v$(strip $(shell git branch --show-current | cut -d'-' -f2))

## current branch name of the external-secrets submodule.
EXTERNAL_SECRETS_BRANCH ?= $(release_version)

## current branch name of the external-secrets-operator sgit push origin main

EXTERNAL_SECRETS_OPERATOR_BRANCH ?= external-secrets-$(release_version)
## check if the parent module branch is main and assign the equivalent external-secrets-operator
## branch instead of deriving the branch name.

## container build tool to use for creating images.
CONTAINER_ENGINE ?= podman

## image name for external-secrets-operator.
EXTERNAL_SECRETS_OPERATOR_IMAGE ?= external-secrets-operator

## image name for external-secrets-operator-bundle.
EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE ?= external-secrets-operator-bundle

## image name for external-secrets.
EXTERNAL_SECRETS_IMAGE ?= external-secrets

## image version to tag the created images with.
IMAGE_VERSION ?= $(release_version)

## image tag makes use of the branch name and
## when branch name is `main` use `latest` as the tag.
ifeq ($(release_version), main)
IMAGE_VERSION = latest
endif

## args to pass during image build
IMAGE_BUILD_ARGS ?= --build-arg RELEASE_VERSION=$(release_version) --build-arg COMMIT_SHA=$(commit_sha) --build-arg SOURCE_URL=$(source_url)

## tailored command to build images.
IMAGE_BUILD_CMD = $(CONTAINER_ENGINE) build $(IMAGE_BUILD_ARGS)

## path to store the tools binary.
TOOL_BIN_DIR = $(strip $(shell git rev-parse --show-toplevel --show-superproject-working-tree | tail -1))/bin/tools

## URL to download Operator Package Manager tool.
OPM_DOWNLOAD_URL = https://github.com/operator-framework/operator-registry/releases/download/$(OPM_TOOL_VERSION)/linux-amd64-opm

## Operator Package Manager tool path.
OPM_TOOL_PATH ?= $(TOOL_BIN_DIR)/opm

## Operator bundle image to use for generating catalog.
OPERATOR_BUNDLE_IMAGE ?=

## Catalog directory where generated catalog will be stored. Directory must have sub-directory with package `openshift-external-secrets-operator` name. #TODO
CATALOG_DIR ?=

.DEFAULT_GOAL := help
## usage summary.
.PHONY: help
help:
	@ echo
	@ echo '  Usage:'
	@ echo ''
	@ echo '    make <target> [flags...]'
	@ echo ''
	@ echo '  Targets:'
	@ echo ''
	@ awk '/^#/{ comment = substr($$0,3) } comment && /^[a-zA-Z][a-zA-Z0-9_-]+ ?:/{ print "   ", $$1, comment }' $(MAKEFILE_LIST) | column -t -s ':' | sort
	@ echo ''
	@ echo '  Flags:'
	@ echo ''
	@ awk '/^#/{ comment = substr($$0,3) } comment && /^[a-zA-Z][a-zA-Z0-9_-]+ ?\?=/{ print "   ", $$1, $$2, comment }' $(MAKEFILE_LIST) | column -t -s '?=' | sort
	@ echo ''

## execute all required targets.
.PHONY: all
all: verify

## checkout submodules branch to match the parent branch.
.PHONY: switch-submodules-branch
switch-submodules-branch:
	cd $(external_secrets_submodule_dir); git checkout $(EXTERNAL_SECRETS_BRANCH); cd - > /dev/null
	cd $(external_secrets_operator_submodule_dir); git checkout $(EXTERNAL_SECRETS_OPERATOR_BRANCH); cd - > /dev/null
	# update with local cache.
	git submodule update

## update submodules revision to match the revision of the origin repository.
.PHONY: update-submodules
update-submodules:
	git submodule update --remote $(external_secrets_submodule_dir)
	git submodule update --remote $(external_secrets_operator_submodule_dir)

## build all the images - operator, operand and operator-bundle.
.PHONY: build-images
build-images: build-operand-images build-operator-image build-bundle-image build-catalog-image

## build operator image.
.PHONY: build-operator-image
build-operator-image:
	$(IMAGE_BUILD_CMD) -f $(external_secrets_containerfile_name) -t $(EXTERNAL_SECRETS_OPERATOR_IMAGE):$(IMAGE_VERSION) .

## build all operand images
.PHONY: build-operand-images
build-operand-images: build-external-secrets-image

## build operator bundle image.
.PHONY: build-bundle-image
build-bundle-image:
	$(IMAGE_BUILD_CMD) -f $(external_secrets_operator_bundle_containerfile_name) -t $(EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE):$(IMAGE_VERSION) .

## build operand cert-manager image.
.PHONY: build-external-secrets-image
build-external-secrets-image:
	$(IMAGE_BUILD_CMD) -f $(external_secrets_containerfile_name) -t $(EXTERNAL_SECRETS_IMAGE):$(IMAGE_VERSION) .

## build operator catalog image.
.PHONY: build-catalog-image
build-catalog-image:
	$(CONTAINER_ENGINE) build -f Containerfile.catalog -t $(CATALOG_IMAGE):$(IMAGE_VERSION) .

## update catalog using the provided bundle image.
.PHONY: update-catalog
update-catalog: get-opm
# validate required parameters are set.
	@(if [ -z $(OPERATOR_BUNDLE_IMAGE) ] || [ -z $(CATALOG_DIR) ]; then echo "\n-- ERROR -- OPERATOR_BUNDLE_IMAGE and CATALOG_DIR parameters must be set for update-catalog target\n"; exit 1; fi)
	@(if [ ! -f $(CATALOG_DIR)/openshift-external-secrets-operator/bundle.yaml ]; then echo "\n-- ERROR -- $(CATALOG_DIR)/openshift-external-secrets-operator/bundle.yaml does not exist\n"; exit 1; fi)

# --migrate-level=bundle-object-to-csv-metadata is used for creating bundle metadata in `olm.csv.metadata` format.
# Refer https://github.com/konflux-ci/build-definitions/blob/main/task/fbc-validation/0.1/TROUBLESHOOTING.md for details.
	$(OPM_TOOL_PATH) render $(OPERATOR_BUNDLE_IMAGE) --migrate-level=bundle-object-to-csv-metadata -o yaml > $(CATALOG_DIR)/openshift-external-secrets-operator/bundle.yaml
	$(OPM_TOOL_PATH) validate $(CATALOG_DIR)

## update catalog and build catalog image.
.PHONY: catalog
catalog: get-opm update-catalog build-catalog-image

## check shell scripts.
.PHONY: verify-shell-scripts
verify-shell-scripts:
	./hack/shell-scripts-linter.sh

## check containerfiles.
.PHONY: verify-containerfiles
verify-containerfiles:
	./hack/containerfile-linter.sh

## verify the changes are working as expected.
.PHONY: verify
verify: verify-shell-scripts verify-containerfiles validate-renovate-config

## update all required contents.
.PHONY: update
update: update-submodules

## get opm(operator package manager) tool.
.PHONY: get-opm
get-opm:
	$(call get-bin,$(OPM_TOOL_PATH),$(TOOL_BIN_DIR),$(OPM_DOWNLOAD_URL))

define get-bin
@[ -f "$(1)" ] || { \
	[ ! -d "$(2)" ] && mkdir -p "$(2)" || true ;\
	echo "Downloading $(3)" ;\
	curl -fL $(3) -o "$(1)" ;\
	chmod +x "$(1)" ;\
}
endef

## clean up temp dirs, images.
.PHONY: clean
clean:
	podman rmi -i $(EXTERNAL_SECRETS_OPERATOR_IMAGE):$(IMAGE_VERSION) \
$(EXTERNAL_SECRETS_IMAGE):$(IMAGE_VERSION) \
$(EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE):$(IMAGE_VERSION) \
$(CATALOG_IMAGE):$(IMAGE_VERSION)

	rm -r $(TOOL_BIN_DIR)

## validate renovate config.
.PHONY: validate-renovate-config
validate-renovate-config:
	./hack/renovate-config-validator.sh