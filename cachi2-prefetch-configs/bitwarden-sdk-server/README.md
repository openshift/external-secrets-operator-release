# prefetch - go.mod

Konflux cachi2 requires the go verison to be in `go X.Y.Z` format, which otherwise
will cause toolchain fetch to fail. Hence maintaining a copy of go.mod and go.sum
of bitwarden-sdk-server submodule in this dir, with the go version in go.mod
in expected format.

## TODO: Remove this dir when go.mod is updated to expected format in upstream.

# prefetch - generics

bitwarden-sdk-server build requires musl-tools package to be present for using
required C libraries. And since the library is not available in all archs, specifically
s390x and ppc64le, we need to build it from source. And we configure `generic` cachi2
package manager to download the tar bundle and install the same during builds.

Refer to the [link](https://github.com/hermetoproject/hermeto/blob/main/docs/generic.md)
for more details on generic prefetch.
