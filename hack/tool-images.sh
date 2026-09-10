#!/usr/bin/env bash
# Pinned tool images and binaries used by hack/*.sh and Makefile.
# Container images use @sha256 digests (content-addressable integrity).
# OPM uses version + per-arch SHA256 checksums verified with sha256sum.
# Renovate updates container images for major/minor versions only (see renovate.json).

export SHELLCHECK_IMAGE="docker.io/koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d"
export HADOLINT_IMAGE="ghcr.io/hadolint/hadolint:v2.15.0@sha256:78cefa24d67e95cac4cdc388652068d0be545bd2926fcbec6f95c1a751d5da32"
export RENOVATE_IMAGE="ghcr.io/renovatebot/renovate:44.4.5@sha256:43ab81533ca965a2a568995ba4d5c175b3637a5460192c9fe32fe66d8249c9b7"
export SKOPEO_IMAGE="registry.access.redhat.com/ubi9/skopeo:9.8-1785444819@sha256:ce2108ada76f38efec293b9a41924122fd000d02af0324994378c4766f301650"

# Operator Package Manager (opm) — checksums from:
# https://github.com/operator-framework/operator-registry/releases/download/${OPM_TOOL_VERSION}/checksums.txt
export OPM_TOOL_VERSION="v1.48.0"
export OPM_DOWNLOAD_BASE_URL="https://github.com/operator-framework/operator-registry/releases/download/${OPM_TOOL_VERSION}"

export OPM_SHA256_darwin_amd64="b14a40541eed5bfef9648e9f37c8cb18d801deb385624c0ac93df56e9f9df45a"
export OPM_SHA256_darwin_arm64="51633a9cf9c1b36b56a4bd0da3d1c31acce0afb1d27fa619b85faa0ecc7b9ba5"
export OPM_SHA256_linux_amd64="0a301826baff730489162caff13e04f7dc16c1a79072cbcbdfc5379d95caef40"
export OPM_SHA256_linux_arm64="4c5ee23f33492c0cd4bdc2cc605728814cc38f889c758f5e7d1ac4e217f80f0c"
export OPM_SHA256_linux_ppc64le="352211a27acded101f8b769c02cd75cb737306a9090becb0649d899cb4bbf228"
export OPM_SHA256_linux_s390x="e029cfd7a76d833aa9e8f6340979b61b9829448fed878bee1efa06dae856732b"

# Verify file contents match an expected SHA-256 hex digest.
# Usage: verify_sha256 <file> <expected_hex>
verify_sha256()
{
	local file="$1"
	local expected="$2"
	local actual

	if [[ ! -f "${file}" ]]; then
		echo "[$(date)] -- ERROR -- cannot verify sha256: \"${file}\" does not exist" >&2
		return 1
	fi
	if [[ ! "${expected}" =~ ^[a-fA-F0-9]{64}$ ]]; then
		echo "[$(date)] -- ERROR -- invalid expected sha256 for \"${file}\": ${expected}" >&2
		return 1
	fi

	actual="$(sha256sum "${file}" | awk '{print $1}')"
	if [[ "${actual}" != "${expected}" ]]; then
		echo "[$(date)] -- ERROR -- sha256 mismatch for \"${file}\"" >&2
		echo "[$(date)] -- ERROR --   expected: ${expected}" >&2
		echo "[$(date)] -- ERROR --   actual:   ${actual}" >&2
		return 1
	fi
	echo "[$(date)] -- INFO  -- sha256 OK for \"${file}\""
	return 0
}

# Assert an image reference is digest-pinned (@sha256:...).
# Usage: require_image_digest <image_ref> [name]
require_image_digest()
{
	local image="$1"
	local name="${2:-image}"

	if [[ ! "${image}" =~ @sha256:[a-fA-F0-9]{64}$ ]]; then
		echo "[$(date)] -- ERROR -- ${name} must be pinned with @sha256:<digest>: ${image}" >&2
		return 1
	fi
	return 0
}
