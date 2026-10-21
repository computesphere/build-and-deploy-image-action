#!/usr/bin/env bash
# Tests for scripts/check-node-version.sh. Run: bash test/check-node-version.test.sh
# Set SKIP_DOCKER=1 to run only the version-table cases.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SCRIPT=scripts/check-node-version.sh
failures=0

expect() { # expect <exit code> <description> <args...>
  local want="$1" desc="$2" out rc
  shift 2
  out=$(bash "$SCRIPT" "$@" 2>&1)
  rc=$?
  if [[ $rc -eq $want ]]; then
    echo "ok   $desc (exit $rc)"
  else
    echo "FAIL $desc: want exit $want, got $rc"
    printf '     %s\n' "$out"
    failures=$((failures + 1))
  fi
}

# Default floor table.
expect 1 "18.20.8 is end of life"          --version v18.20.8
expect 1 "20.20.2 is end of life"          --version v20.20.2
expect 1 "22.23.3 is below 22.23.4"        --version v22.23.3
expect 0 "22.23.4 is fixed"                --version v22.23.4
expect 0 "22.24.0 is above the floor"      --version v22.24.0
expect 1 "24.21.0 is below 24.22.1"        --version v24.21.0
expect 0 "24.22.1 is fixed"                --version v24.22.1
expect 1 "26.7.0 is below 26.12.1"         --version v26.7.0
expect 0 "26.12.1 is fixed"                --version v26.12.1
expect 1 "25.1.0 is an end-of-life odd line" --version v25.1.0
expect 1 "23.11.1 is an end-of-life odd line" --version v23.11.1
expect 0 "27.0.0 is newer than the table"  --version v27.0.0
expect 2 "garbage version is an error"     --version not-a-version

# Warn mode (the action's default): findings and check errors warn, exit 0.
NODE_VERSION_ON_FAIL=warn expect 0 "warn: 22.23.3 warns, exit 0"   --version v22.23.3
NODE_VERSION_ON_FAIL=warn expect 0 "warn: 20.20.2 warns, exit 0"   --version v20.20.2
NODE_VERSION_ON_FAIL=warn expect 0 "warn: garbage warns, exit 0"   --version not-a-version
out=$(NODE_VERSION_ON_FAIL=warn bash "$SCRIPT" --version v22.23.3 2>&1)
if [[ "$out" == *"::warning::Node.js v22.23.3 is below the security floor"* && "$out" != *"::error::"* ]]; then
  echo "ok   warn: message is a ::warning:: annotation"
else
  echo "FAIL warn: want a ::warning:: annotation, got: $out"; failures=$((failures + 1))
fi
NODE_VERSION_ON_FAIL=warn NODE_VERSION_FLOORS="bogus" expect 0 "warn: invalid override warns, exit 0" --version v22.23.4

# Override table.
NODE_VERSION_FLOORS="22.30.0" expect 1 "override raises the 22 floor" --version v22.23.4
NODE_VERSION_FLOORS="20.20.2,22.23.4" expect 0 "override can allow 20" --version v20.20.2
NODE_VERSION_FLOORS="bogus" expect 2 "invalid override is an error" --version v22.23.4

if [[ "${SKIP_DOCKER:-}" != 1 ]]; then
  tag=check-node-version-test
  ctx=test/node-version
  docker build -q -t "$tag:fake-22.23.3" --build-arg NODE_VERSION=22.23.3 -f "$ctx/Dockerfile.fake-node" "$ctx" >/dev/null || exit 2
  docker build -q -t "$tag:fake-24.22.1" --build-arg NODE_VERSION=24.22.1 -f "$ctx/Dockerfile.fake-node" "$ctx" >/dev/null || exit 2
  docker build -q -t "$tag:no-shell" -f "$ctx/Dockerfile.no-shell" "$ctx" >/dev/null || exit 2
  docker pull -q busybox:1.37 >/dev/null || exit 2
  expect 1 "image with node 22.23.3 fails"  --image "$tag:fake-22.23.3"
  NODE_VERSION_ON_FAIL=warn expect 0 "warn: image with node 22.23.3 warns" --image "$tag:fake-22.23.3"
  NODE_VERSION_ON_FAIL=warn expect 0 "warn: missing image warns"  --image "$tag:does-not-exist"
  expect 0 "image with node 24.22.1 passes" --image "$tag:fake-24.22.1"
  expect 0 "image without node is skipped"  --image busybox:1.37
  expect 0 "image without a shell is skipped" --image "$tag:no-shell"
  docker image rm -f "$tag:fake-22.23.3" "$tag:fake-24.22.1" "$tag:no-shell" >/dev/null
fi

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
