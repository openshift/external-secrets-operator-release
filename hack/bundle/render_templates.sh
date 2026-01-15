#!/usr/bin/env bash

set -x

declare MANIFESTS_DIR
declare METADATA_DIR
declare IMAGES_DIGEST_CONF_FILE
declare EXTERNAL_SECRETS_IMAGE
declare BITWARDEN_SDK_SERVER_IMAGE
declare EXTERNAL_SECRETS_OPERATOR_IMAGE

CSV_FILE_NAME="external-secrets-operator.clusterserviceversion.yaml"
ANNOTATIONS_FILE_NAME="annotations.yaml"
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

update_csv_manifest()
{
	CSV_FILE="${MANIFESTS_DIR}/${CSV_FILE_NAME}"
	if [[ ! -f "${CSV_FILE}" ]]; then
		log_error "operator csv file \"${CSV_FILE}\" does not exist"
		exit 1
	fi

	## replace external-secrets operand related images
	sed -i "s#ghcr.io/external-secrets/external-secrets.*#${EXTERNAL_SECRETS_IMAGE}#g" "${CSV_FILE}"

	## replace bitwrden-sdk-server images
	sed -i "s#ghcr.io/external-secrets/bitwarden-sdk-server.*#${BITWARDEN_SDK_SERVER_IMAGE}#g" "${CSV_FILE}"

	## replace external-secrets-operator image
	sed -i "s#openshift.io/external-secrets-operator.*#${EXTERNAL_SECRETS_OPERATOR_IMAGE}#g" "${CSV_FILE}"

	## add annotations
	yq e -i ".metadata.annotations.createdAt=\"$(date -u +'%Y-%m-%dT%H:%M:%S')\"" "${CSV_FILE}"
}

update_annotations_metadata() {
	ANNOTATION_FILE="${METADATA_DIR}/${ANNOTATIONS_FILE_NAME}"
	if [[ ! -f ${ANNOTATION_FILE} ]]; then
		log_error "annotations metadata file \"${CSV_FILE}\" does not exist"
		exit 1
	fi

	# add annotations
	yq e -i '.annotations."operators.operatorframework.io.bundle.package.v1"="openshift-external-secrets-operator"' "${ANNOTATION_FILE}"
}

usage()
{
	echo -e "usage:\n\t$(basename "${BASH_SOURCE[0]}")" \
		'"<MANIFESTS_DIR>"' \
		'"<METADATA_DIR>"' \
		'"<IMAGES_DIGEST_CONF_FILE>"'
	exit 1
}

##############################################
###############  MAIN  #######################
##############################################

if [[ $# -lt 3 ]]; then
	usage
fi

MANIFESTS_DIR=$1
METADATA_DIR=$2
IMAGES_DIGEST_CONF_FILE=$3

log_info "$*"

if [[ ! -d ${MANIFESTS_DIR} ]]; then
	log_error "manifests directory \"${MANIFESTS_DIR}\" does not exist"
	exit 1
fi

if [[ ! -d ${METADATA_DIR} ]]; then
	log_error "metadata directory \"${METADATA_DIR}\" does not exist"
	exit 1
fi

if [[ ! -f ${IMAGES_DIGEST_CONF_FILE} ]]; then
	log_error "image digests conf file \"${IMAGES_DIGEST_CONF_FILE}\" does not exist"
	exit 1
fi

# shellcheck source=/dev/null
source "${IMAGES_DIGEST_CONF_FILE}"

if [[ -z ${EXTERNAL_SECRETS_IMAGE} ]] || [[ -z ${EXTERNAL_SECRETS_OPERATOR_IMAGE} ]] || [[ -z ${BITWARDEN_SDK_SERVER_IMAGE} ]]; then
	log_error "one or all of \"${EXTERNAL_SECRETS_IMAGE}\", \"${BITWARDEN_SDK_SERVER_IMAGE}\", \"${EXTERNAL_SECRETS_OPERATOR_IMAGE}\" is not set"
	exit 1
fi

update_csv_manifest
update_annotations_metadata

exit 0
