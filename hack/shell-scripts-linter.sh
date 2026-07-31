#!/usr/bin/env bash

# shellcheck disable=SC1091 # sourced file path is runtime-resolved
source "$(dirname "${BASH_SOURCE[0]}")/tool-images.sh"

verify_script()
{
  require_image_digest "${SHELLCHECK_IMAGE}" "SHELLCHECK_IMAGE"
  if ! find . -type f -name '*.sh' '!' -path './external-secrets/*' '!' -path './external-secrets-operator/*' \
		-printf "[$(date)] -- INFO  -- checking file %p\n" \
		-exec podman run --rm -v "$PWD:/mnt:Z" -w /mnt "${SHELLCHECK_IMAGE}" '{}' + ; then
		exit 1
	fi
}

##############################################
###############  MAIN  #######################
##############################################

verify_script

exit 0
