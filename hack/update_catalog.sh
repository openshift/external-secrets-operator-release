#!/usr/bin/env bash

declare CONFIGS_DIR
declare EXTERNAL_SECRETS_OPERATOR_IMAGE
declare EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE
declare EXTERNAL_SECRETS_IMAGE
declare KUBE_RBAC_PROXY_IMAGE

CATALOG_MANIFEST_FILE_NAME="catalog.yaml"

update_catalog_manifest()
{
	CATALOG_MANIFEST_FILE="${CONFIGS_DIR}/${CATALOG_MANIFEST_FILE_NAME}"
	if [[ ! -f "${CATALOG_MANIFEST_FILE}" ]]; then
		echo "[$(date)] -- ERROR -- catalog manifest file \"${CATALOG_MANIFEST_FILE}\" does not exist"
		exit 1
	fi

	## replace external-secrets operand related images
	sed -i "s#registry.redhat.io/external-secrets/external-secrets-rhel9.*#${EXTERNAL_SECRETS_IMAGE}#g" "${CATALOG_MANIFEST_FILE}"

	## replace external-secrets-operator image
	sed -i "s#registry.redhat.io/external-secrets/external-secrets-operator-rhel9.*#${EXTERNAL_SECRETS_OPERATOR_IMAGE}#g" "${CATALOG_MANIFEST_FILE}"

	## replace external-secrets-operator-bundle image
	sed -i "s#registry.redhat.io/external-secrets/external-secrets-operator-bundle.*#${EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE}#g" "${CATALOG_MANIFEST_FILE}"

	## replace kube-rbac-proxy image
	sed -i "s#registry.redhat.io/openshift4/ose-kube-rbac-proxy-rhel9.*#${KUBE_RBAC_PROXY_IMAGE}#g" "${CATALOG_MANIFEST_FILE}"
}

usage()
{
	echo -e "usage:\n\t$(basename "${BASH_SOURCE[0]}")" \
		'"<CATALOG_CONFIG_DIR>"' \
		'"<EXTERNAL_SECRETS_OPERATOR_IMAGE>"' \
		'"<EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE>"' \
		'"<EXTERNAL_SECRETS_IMAGE>"' \
		'"<KUBE_RBAC_PROXY_IMAGE>"'
	exit 1
}

##############################################
###############  MAIN  #######################
##############################################

if [[ $# -ne 6 ]]; then
  usage
fi

CONFIGS_DIR=$1
EXTERNAL_SECRETS_OPERATOR_IMAGE=$2
EXTERNAL_SECRETS_OPERATOR_BUNDLE_IMAGE=$3
EXTERNAL_SECRETS_IMAGE=$4
KUBE_RBAC_PROXY_IMAGE=$5

echo "[$(date)] -- INFO  -- $*"

if [[ ! -d ${CONFIGS_DIR} ]]; then
  echo "[$(date)] -- ERROR -- manifests directory \"${MANIFESTS_DIR}\" does not exist"
	exit 1
fi

update_catalog_manifest

exit 0