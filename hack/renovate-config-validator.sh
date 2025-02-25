#!/usr/bin/env bash

validate_config()
{
	if ! podman run -e "LOG_LEVEL=debug" --rm -v "./renovate.json:/tmp/validate/renovate.json" ghcr.io/renovatebot/renovate \
		renovate-config-validator --strict /tmp/validate/renovate.json; then
		exit 1
	fi
}

##############################################
###############  MAIN  #######################
##############################################

validate_config

exit 0