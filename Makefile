## container build tool to use for creating images.
CONTAINER_ENGINE ?= podman

## image name for external-secrets-operator catalog.
CATALOG_IMAGE ?= external-secrets-operator-catalog

## image version to tag the created images with.
IMAGE_VERSION ?= latest

## path to store the tools binary.
TOOL_BIN_DIR = $(strip $(shell git rev-parse --show-toplevel --show-superproject-working-tree | tail -1))/bin/tools

## Operator Package Manager tool to download.
OPM_TOOL_VERSION ?= v1.48.0

## URL to download Operator Package Manager tool.
OPM_DOWNLOAD_URL = https://github.com/operator-framework/operator-registry/releases/download/$(OPM_TOOL_VERSION)/$(shell go env GOOS)-$(shell go env GOARCH)-opm

## Operator Package Manager tool path.
OPM_TOOL_PATH ?= $(TOOL_BIN_DIR)/opm

## Operator bundle image to use for generating catalog.
OPERATOR_BUNDLE_IMAGE ?=

## Catalog directory where generated catalog will be stored (e.g. catalogs/v4.21/catalog).
CATALOG_DIR ?=

## Bundle file name to generate under the package directory (e.g. bundle-v1.2.0.yaml).
BUNDLE_FILE_NAME ?=

## OCP versions to replicate the bundle to: no | yes | 4.19,4.20 | 4.19-4.22
REPLICATE_BUNDLE_FILE_IN_CATALOGS ?= no

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

## build operator catalog image.
.PHONY: build-catalog-image
build-catalog-image:
	$(CONTAINER_ENGINE) build -f Containerfile.catalog -t $(CATALOG_IMAGE):$(IMAGE_VERSION) .

## update catalog using the provided bundle image.
.PHONY: update-catalog
update-catalog: get-opm
	@test -n "$(OPERATOR_BUNDLE_IMAGE)" || { echo "OPERATOR_BUNDLE_IMAGE is required"; exit 1; }
	@test -n "$(CATALOG_DIR)" || { echo "CATALOG_DIR is required (e.g. catalogs/v4.21/catalog)"; exit 1; }
	@test -n "$(BUNDLE_FILE_NAME)" || { echo "BUNDLE_FILE_NAME is required (e.g. bundle-v1.2.0.yaml)"; exit 1; }
	@#ex.: make update-catalog OPERATOR_BUNDLE_IMAGE=registry.stage.redhat.io/external-secrets-operator/external-secrets-operator-bundle@sha256:8cbe4dcef17c08f845be0bd14d83e5a0047f3e09d5261f63ec50a3d7506d72ac CATALOG_DIR=catalogs/v4.19/catalog BUNDLE_FILE_NAME=bundle-v1.2.0.yaml REPLICATE_BUNDLE_FILE_IN_CATALOGS=4.19-5.0
	./hack/update_catalog.sh $(OPM_TOOL_PATH) $(OPERATOR_BUNDLE_IMAGE) $(CATALOG_DIR) $(BUNDLE_FILE_NAME) $(REPLICATE_BUNDLE_FILE_IN_CATALOGS)

## update catalog and build catalog image.
.PHONY: catalog
catalog: get-opm build-catalog-image

# Only run update-catalog if OPERATOR_BUNDLE_IMAGE is set
ifneq ($(OPERATOR_BUNDLE_IMAGE),)
    catalog: get-opm update-catalog build-catalog-image
endif

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
	$(CONTAINER_ENGINE) rmi -i $(CATALOG_IMAGE):$(IMAGE_VERSION)
	rm -r $(TOOL_BIN_DIR)

## validate renovate config.
.PHONY: validate-renovate-config
validate-renovate-config:
	./hack/renovate-config-validator.sh
