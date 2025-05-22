## local variables.
external_secrets_submodule_dir = external-secrets
external_secrets_operator_submodule_dir = external-secrets-operator
external_secrets_containerfile_name = Containerfile.external-secrets
external_secrets_operator_containerfile_name = Containerfile.external-secrets-operator
external_secrets_operator_bundle_containerfile_name = Containerfile.external-secrets-operator.bundle
commit_sha = $(strip $(shell git rev-parse HEAD))
source_url = $(strip $(shell git remote get-url origin))

## release version to be used for image tags and build args to add labels to images.
RELEASE_VERSION = v0.1

## current branch name of the external-secrets submodule.
EXTERNAL_SECRETS_BRANCH ?= release-0.14

## current branch name of the external-secrets-operator submodule
EXTERNAL_SECRETS_OPERATOR_BRANCH ?= release-0.1

## container build tool to use for creating images.
CONTAINER_ENGINE ?= podman

## image name for external-secrets-operator.
EXTERNAL_SECRETS_OPERATOR_IMAGE ?= external-secrets-operator

## image name for external-secrets-operator-bundle.
EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE ?= external-secrets-operator-bundle

## image name for external-secrets.
EXTERNAL_SECRETS_IMAGE ?= external-secrets

## image version to tag the created images with.
IMAGE_VERSION ?= $(RELEASE_VERSION)

## args to pass during image build
IMAGE_BUILD_ARGS ?= --build-arg RELEASE_VERSION=$(RELEASE_VERSION) --build-arg COMMIT_SHA=$(commit_sha) --build-arg SOURCE_URL=$(source_url)

## tailored command to build images.
IMAGE_BUILD_CMD = $(CONTAINER_ENGINE) build $(IMAGE_BUILD_ARGS)

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
build-images: build-operand-images build-operator-image build-bundle-image

## build operator image.
.PHONY: build-operator-image
build-operator-image:
	$(IMAGE_BUILD_CMD) -f $(external_secrets_operator_containerfile_name) -t $(EXTERNAL_SECRETS_OPERATOR_IMAGE):$(IMAGE_VERSION) .

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

## clean up temp dirs, images.
.PHONY: clean
clean:
	podman rmi -i $(EXTERNAL_SECRETS_OPERATOR_IMAGE):$(IMAGE_VERSION) \
$(EXTERNAL_SECRETS_IMAGE):$(IMAGE_VERSION) \
$(EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE):$(IMAGE_VERSION)

## validate renovate config.
.PHONY: validate-renovate-config
validate-renovate-config:
	./hack/renovate-config-validator.sh
