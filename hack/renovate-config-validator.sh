#!/usr/bin/env bash

# shellcheck disable=SC1091 # sourced file path is runtime-resolved
source "$(dirname "${BASH_SOURCE[0]}")/tool-images.sh"

validate_config()
{
	require_image_digest "${RENOVATE_IMAGE}" "RENOVATE_IMAGE"
	if ! podman run -e "LOG_LEVEL=debug" --rm -v "./renovate.json:/tmp/validate/renovate.json:Z" -w /tmp/validate \
		"${RENOVATE_IMAGE}" \
		renovate-config-validator --strict /tmp/validate/renovate.json; then
		exit 1
	fi
}

##############################################
###############  MAIN  #######################
##############################################

validate_config

exit 0
