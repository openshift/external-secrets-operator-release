#!/usr/bin/env bash

#
# Example usage:
# ./update_catalog.sh ./bin/tools/opm \
# registry.stage.redhat.io/external-secrets-operator/external-secrets-operator-bundle@sha256:4114321b0ab6ceb882f26501ff9b22214d90b83d92466e7c5a62217f592c1fed \
# catalogs/v4.19/catalog \
# bundle-v1.2.0.yaml \
# 4.19-5.0
#
# REPLICATE_BUNDLE_FILE_IN_CATALOGS accepts:
#   no                          - do not replicate
#   yes                         - replicate to all other catalog directories
#   4.19,4.20,4.21              - replicate to specific OCP versions
#   4.19-4.22                   - replicate to OCP v4.19 through v4.22 (inclusive)
#   4.19-5.0                    - replicate across major versions (uses existing catalog dirs in range)
#   4.19,4.21-4.22,5.0          - mix of versions and ranges
#
# channel.yaml is not updated by this script. Update channel.yaml in each affected
# catalog before running this script — opm validate runs automatically after bundle
# generation and replication. See the "Updating the catalog" section in README.MD.
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
	echo -e "[$(date)] ${RED_COLOR_TEXT}-- ERROR --${REVERT_COLOR_TEXT} ${1}" >&2
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
	media_type="$(podman run -e REGISTRY_AUTH_FILE="/tmp/auth.json" --rm -v "${auth_file}:/tmp/auth.json:Z" \
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
	echo -e "\nREPLICATE_BUNDLE_FILE_IN_CATALOGS: no | yes | comma-separated OCP versions (e.g. 4.19,4.20) | version range (e.g. 4.19-4.22 or 4.19-5.0)"
	exit 1
}

ocp_version_to_int()
{
	local version="${1}"

	if [[ ! "${version}" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
		log_error "invalid OCP version \"${version}\", expected format like 4.19"
		return 1
	fi

	echo $(( BASH_REMATCH[1] * 1000 + BASH_REMATCH[2] ))
}

expand_ocp_version_range()
{
	local range="${1}"
	local start_version end_version start_int end_int catalog_dir version version_int
	local -a versions_in_range=()

	if [[ ! "${range}" =~ ^([0-9]+\.[0-9]+)-([0-9]+\.[0-9]+)$ ]]; then
		log_error "invalid OCP version range \"${range}\", expected format like 4.19-4.22 or 4.19-5.0"
		return 1
	fi

	start_version="${BASH_REMATCH[1]}"
	end_version="${BASH_REMATCH[2]}"
	start_int="$(ocp_version_to_int "${start_version}")" || return 1
	end_int="$(ocp_version_to_int "${end_version}")" || return 1

	if (( start_int > end_int )); then
		log_error "invalid OCP version range (start > end): \"${range}\""
		return 1
	fi

	for catalog_dir in catalogs/v*/catalog; do
		version="${catalog_dir#catalogs/v}"
		version="${version%/catalog}"
		version_int="$(ocp_version_to_int "${version}")" || continue
		if (( version_int >= start_int && version_int <= end_int )); then
			versions_in_range+=("${version}")
		fi
	done

	if [[ "${#versions_in_range[@]}" -eq 0 ]]; then
		log_error "no catalog directories found for OCP version range \"${range}\""
		return 1
	fi

	for version in "${versions_in_range[@]}"; do
		echo "${version}"
	done
}

parse_replicate_ocp_versions()
{
	local spec="${1}"
	local -a tokens=()
	local -A seen_versions=()
	local token version expanded_versions

	IFS=',' read -r -a tokens <<< "${spec}"
	for token in "${tokens[@]}"; do
		token="${token// /}"
		if [[ -z "${token}" ]]; then
			continue
		fi

		if [[ "${token}" =~ ^[0-9]+\.[0-9]+-[0-9]+\.[0-9]+$ ]]; then
			expanded_versions="$(expand_ocp_version_range "${token}")" || exit 1
			while IFS= read -r version; do
				if [[ -z "${seen_versions[${version}]:-}" ]]; then
					seen_versions["${version}"]=1
					echo "${version}"
				fi
			done <<< "${expanded_versions}"
		elif [[ "${token}" =~ ^[0-9]+\.[0-9]+$ ]]; then
			if [[ -z "${seen_versions[${token}]:-}" ]]; then
				seen_versions["${token}"]=1
				echo "${token}"
			fi
		else
			log_error "invalid OCP version \"${token}\", expected format like 4.19 or 4.19-4.22"
			exit 1
		fi
	done
}

validate_replicate_ocp_versions_spec()
{
	if [[ -z "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" ]]; then
		log_error "replicate target cannot be empty, use \"no\" to skip replication"
		exit 1
	fi

	case "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" in
		yes|no)
			return
			;;
	esac

	mapfile -t _parsed_versions < <(parse_replicate_ocp_versions "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}")
	if [[ "${#_parsed_versions[@]}" -eq 0 ]]; then
		log_error "no OCP versions parsed from \"${REPLICATE_BUNDLE_FILE_IN_CATALOGS}\""
		exit 1
	fi
}

validate_catalog_dir()
{
	local catalog_dir="${1}"

	log_info "validating catalog \"${catalog_dir}\""
	if ! "${OPM_TOOL_PATH}" validate "${catalog_dir}"; then
		log_error "failed to validate catalog \"${catalog_dir}\""
		exit 1
	fi
}

replicate_catalog_bundle()
{
	local bundle_file target_dir target_catalog_dir ocp_version

	if [[ "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" == "no" ]]; then
		return
	fi

	bundle_file="${CATALOG_DIR}/${EXTERNAL_SECRETS_OPERATOR_CATALOG_NAME}/${BUNDLE_FILE_NAME}"

	if [[ "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}" == "yes" ]]; then
		while IFS= read -r target_dir; do
			log_info "replicating catalog bundle to \"${target_dir}/${BUNDLE_FILE_NAME}\""
			cp "${bundle_file}" "${target_dir}/${BUNDLE_FILE_NAME}"
			target_catalog_dir="$(dirname "${target_dir}")"
			validate_catalog_dir "${target_catalog_dir}"
		done < <(find catalogs/*/catalog/openshift-external-secrets-operator -type d ! -path "${CATALOG_DIR}/*")
		return
	fi

	mapfile -t ocp_versions < <(parse_replicate_ocp_versions "${REPLICATE_BUNDLE_FILE_IN_CATALOGS}")
	for ocp_version in "${ocp_versions[@]}"; do
		target_catalog_dir="catalogs/v${ocp_version}/catalog"
		target_dir="${target_catalog_dir}/${EXTERNAL_SECRETS_OPERATOR_CATALOG_NAME}"
		if [[ "${target_dir}" == "${CATALOG_DIR}/${EXTERNAL_SECRETS_OPERATOR_CATALOG_NAME}" ]]; then
			log_info "skipping replication to source catalog \"${target_dir}\""
			continue
		fi
		if [[ ! -d "${target_dir}" ]]; then
			log_error "catalog directory for OCP v${ocp_version} does not exist: \"${target_dir}\""
			exit 1
		fi
		log_info "replicating catalog bundle to \"${target_dir}/${BUNDLE_FILE_NAME}\""
		cp "${bundle_file}" "${target_dir}/${BUNDLE_FILE_NAME}"
		validate_catalog_dir "${target_catalog_dir}"
	done
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
	log_error "\"${OPM_TOOL_PATH}\" does not exist or does not have execute permissions"
	exit 1
fi

if [[ -z "${BUNDLE_FILE_NAME}" ]]; then
	log_error "bundle file name cannot be empty"
	exit 1
fi

validate_replicate_ocp_versions_spec

verify_bundle_image

render_catalog_bundle

replicate_catalog_bundle

exit 0
