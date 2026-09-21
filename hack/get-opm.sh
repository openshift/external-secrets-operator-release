#!/usr/bin/env bash
# Download the pinned opm binary into TOOL_BIN_DIR and verify its SHA-256 checksum.

set -euo pipefail

# shellcheck disable=SC1091 # sourced file path is runtime-resolved
source "$(dirname "${BASH_SOURCE[0]}")/tool-images.sh"

TOOL_BIN_DIR="${1:?TOOL_BIN_DIR is required}"
OPM_TOOL_PATH="${TOOL_BIN_DIR}/opm"

os="$(go env GOOS)"
arch="$(go env GOARCH)"
checksum_var="OPM_SHA256_${os}_${arch}"

if [[ -z "${!checksum_var:-}" ]]; then
	echo "[$(date)] -- ERROR -- no pinned sha256 for opm ${os}/${arch} (OPM_TOOL_VERSION=${OPM_TOOL_VERSION})" >&2
	exit 1
fi
expected_sha256="${!checksum_var}"
download_url="${OPM_DOWNLOAD_BASE_URL}/${os}-${arch}-opm"

mkdir -p "${TOOL_BIN_DIR}"

if [[ -f "${OPM_TOOL_PATH}" ]]; then
	if verify_sha256 "${OPM_TOOL_PATH}" "${expected_sha256}"; then
		exit 0
	fi
	echo "[$(date)] -- INFO  -- existing opm failed checksum check; re-downloading"
	rm -f "${OPM_TOOL_PATH}"
fi

echo "[$(date)] -- INFO  -- downloading opm ${OPM_TOOL_VERSION} (${os}/${arch})"
echo "[$(date)] -- INFO  --   ${download_url}"
curl -fL "${download_url}" -o "${OPM_TOOL_PATH}"
chmod +x "${OPM_TOOL_PATH}"

if ! verify_sha256 "${OPM_TOOL_PATH}" "${expected_sha256}"; then
	rm -f "${OPM_TOOL_PATH}"
	exit 1
fi
