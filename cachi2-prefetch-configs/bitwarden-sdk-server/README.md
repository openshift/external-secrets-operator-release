# prefetch - go.mod

Konflux cachi2 requires the go verison to be in `go X.Y.Z` format, which otherwise
will cause toolchain fetch to fail. Hence maintaining a copy of go.mod and go.sum
of bitwarden-sdk-server submodule in this dir, with the go version in go.mod
in expected format.

## TODO: Remove this dir when go.mod is updated to expected format in upstream.
