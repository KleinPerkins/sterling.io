#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Build outside synced Documents: File Provider FinderInfo breaks ad-hoc signing.
project_key=$(printf '%s' "$PWD" | shasum -a 256 | cut -c 1-12)
build_temp="${TMPDIR:-/private/tmp}"
export STERLING_BUILD_ROOT="${build_temp%/}/sterling-feasibility-$project_key"
mkdir -p "$STERLING_BUILD_ROOT"
export CLANG_MODULE_CACHE_PATH="$STERLING_BUILD_ROOT/clang-module-cache"
args=("$@")
if [[ "${1:-}" == test ]]; then
    swift_path=$(xcrun --find swift)
    testing_plugin="${swift_path:h:h}/lib/swift/host/plugins/testing/libTestingMacros.dylib"
    args+=(--disable-xctest)
    if [[ -f "$testing_plugin" ]]; then
        args+=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin")
    fi
fi
exec xcrun swift "${args[@]}" --scratch-path "$STERLING_BUILD_ROOT/build" --cache-path "$STERLING_BUILD_ROOT/cache" --config-path "$STERLING_BUILD_ROOT/config" --security-path "$STERLING_BUILD_ROOT/security" --disable-sandbox
