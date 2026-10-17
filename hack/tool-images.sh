#!/usr/bin/env bash
# Pinned tool images used by hack/*.sh.
# Container images use @sha256 digests (content-addressable integrity).
# Renovate updates these for major/minor versions only (see renovate.json).

export SHELLCHECK_IMAGE="docker.io/koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d"
export HADOLINT_IMAGE="ghcr.io/hadolint/hadolint:v2.15.0@sha256:78cefa24d67e95cac4cdc388652068d0be545bd2926fcbec6f95c1a751d5da32"
export RENOVATE_IMAGE="ghcr.io/renovatebot/renovate:44.165.1@sha256:455f4169a364a4c8bdc38a08694e3509649f3d7cb9aaea35c86946b38015ac47"

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
