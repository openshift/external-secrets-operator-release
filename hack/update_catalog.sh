#!/usr/bin/env bash

#
# Example usage:
# ./update_catalog.sh ./bin/tools/opm \
# registry.stage.redhat.io/external-secrets-operator/external-secrets-operator-bundle@sha256:4114321b0ab6ceb882f26501ff9b22214d90b83d92466e7c5a62217f592c1fed \
# catalogs/v4.19/catalog \
# bundle-v0.1.0.yaml \
# yes
#

declare OPM_TOOL_PATH
declare OPERATOR_BUNDLE_IMAGE
declare CATALOG_DIR
declare BUNDLE_FILE_NAME
declare REPLICATE_BUNDLE_FILE_IN_CATALOGS

EXTERNAL_SECRETS_OPERATOR_CATALOG_NAME="openshift-external-secrets-operator"
GREEN_COLOR_TEXT='\033[0;32m'
RED_COLOR_TEXT='\033[0;31m'
REVERT_COLOR_TEXT='\033[0m'

log_info()
{
	echo -e "[$(date)] ${GREEN_COLOR_TEXT}-- INFO  --${REVERT_COLOR_TEXT} ${1}"
}

log_error()
{
	echo -e "[$(date)] ${RED_COLOR_TEXT}-- ERROR --${REVERT_COLOR_TEXT} ${1}"
}

verify_bundle_image()
{
	auth_file=""
	if [[ -n ${REGISTRY_AUTH_FILE} ]]; then
		auth_file=${REGISTRY_AUTH_FILE}
	elif [[ -f ${XDG_RUNTIME_DIR}/containers/auth.json ]]; then
		auth_file=${XDG_RUNTIME_DIR}/containers/auth.json
	elif [[ -f ${HOME}/.docker/config.json ]]; then
		auth_file=${HOME}/.docker/config.json
	else
		log_error "registry auth config lookup failed, expected REGISTRY_AUTH_FILE env var to be set, \
			or config to be present in podman/docker recognised path"
		exit 1
	fi

	log_info "inspecting ${OPERATOR_BUNDLE_IMAGE} bundle image"
	media_type="$(podman run -e REGISTRY_AUTH_FILE="/tmp/auth.json" --rm -v "${auth_file}:/tmp/auth.json:z" \
		quay.io/skopeo/stable:latest inspect --raw docker://"${OPERATOR_BUNDLE_IMAGE}" | jq -r .mediaType)"

	case $media_type in
		application/vnd.oci.image.manifest.v1+json|application/vnd.docker.distribution.manifest.v2+json)
		;;
	*)
		log_error "bundle image not having expected media type, possibly index image was created"
		exit 1
	esac

	return
}

render_catalog_bundle()
{
	# --migrate-level=bundle-object-to-csv-metadata is used for creating bundle metadata in `olm.csv.metadata` format.
	# Refer https://github.com/konflux-ci/build-definitions/blob/main/task/fbc-validation/0.1/TROUBLESHOOTING.md for details.
	render_cmd_args="--migrate-level=bundle-object-to-csv-metadata"

	bundle_file="${CATALOG_DIR}/${EXTERNAL_SECRETS_OPERATOR_CATALOG_NAME}/${BUNDLE_FILE_NAME}"
	log_info "generating catalog bundle \"${bundle_file}\""
	if ! "${OPM_TOOL_PATH}" render "${OPERATOR_BUNDLE_IMAGE}" $render_cmd_args -o yaml > "${bundle_file}"; then
		log_error "failed to render catalog bundle"
		exit 1
	fi

	if ! "${OPM_TOOL_PATH}" validate "${CATALOG_DIR}"; then
		log_error "failed to validate catalog"
		exit 1
	fi
}

usage()
{
	echo -e "usage:\n\t$(basename "${BASH_SOURCE[0]}")" \
		'"<OPM_TOOL_PATH>"' \
		'"<OPERATOR_BUNDLE_IMAGE>"' \
		'"<CATALOG_DIR>"' \
		'"<BUNDLE_FILE_NAME>"' \
		'"<REPLICATE_BUNDLE_FILE_IN_CATALOGS>"'
	exit 1
}

replicate_catalog_bundle()
{
	if [[ "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" == "no" ]]; then
		return
	fi

	bundle_file="${CATALOG_DIR}/${EXTERNAL_SECRETS_OPERATOR_CATALOG_NAME}/${BUNDLE_FILE_NAME}"

	find catalogs/*/catalog/openshift-external-secrets-operator -type d ! -path "${CATALOG_DIR}/*" -exec /bin/cp "${bundle_file}" {} \; -print
}

##############################################
###############  MAIN  #######################
##############################################

if [[ $# -ne 5 ]]; then
	usage
fi

OPM_TOOL_PATH=$1
OPERATOR_BUNDLE_IMAGE=$2
CATALOG_DIR=$3
BUNDLE_FILE_NAME=$4
REPLICATE_BUNDLE_FILE_IN_CATALOGS=$5

log_info "$*"

if [[ ! -d "${CATALOG_DIR}" ]]; then
	log_error "catalog directory \"${CATALOG_DIR}\" does not exist"
	exit 1
fi

if [[ ! -x "${OPM_TOOL_PATH}" ]]; then
	log_error "\"${OPM_TOOL_PATH}\" does not exist or does not execute permissions"
	exit 1
fi

if [[ -z "${BUNDLE_FILE_NAME}" ]]; then
	log_error "bundle file name cannot be empty"
	exit 1
fi

if [[ -z "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" ]] || [[ "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" != @(yes|no) ]]; then
	log_error "invalid value provided for \"REPLICATE_BUNDLE_FILE_IN_CATALOGS\", must be \"yes\" or \"no\""
	exit 1
fi

verify_bundle_image

render_catalog_bundle

replicate_catalog_bundle

exit 0
