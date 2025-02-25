#!/usr/bin/env bash

verify_script()
{
  if ! find . -type f -name '*.sh' '!' -path './external-secrets/*' '!' -path './external-secrets-operator/*' \
		-printf "[$(date)] -- INFO  -- checking file %p\n" \
		-exec podman run --rm -v "$PWD:/mnt" docker.io/koalaman/shellcheck:stable '{}' + ; then
		exit 1
	fi
}

##############################################
###############  MAIN  #######################
##############################################

verify_script

exit 0