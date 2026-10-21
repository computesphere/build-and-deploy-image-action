#!/usr/bin/env bash
# Fails when a Node.js version is below the security floor.
#
#   check-node-version.sh --image <image>    run `node -v` inside a built image
#   check-node-version.sh --version <vX.Y.Z> check a version string
#
# Exit codes: 0 = OK or no Node in the image (skipped), 1 = below the floor,
# 2 = usage error or the check itself could not run.
#
# NODE_VERSION_ON_FAIL=warn turns every finding and every check error into a
# GitHub ::warning:: and exits 0 (the action's default in v1); the default,
# error, prints ::error:: and exits 1 or 2.
#
# The floor is one minimum version per supported major line. A version passes
# when its major line has a floor and it is at or above it, or when its major
# is newer than every line in the table (a release line that started after
# the fix). Anything older than the oldest listed line, and any unlisted line
# in between (odd, non-LTS lines and end-of-life lines), fails.
#
# Override the table with NODE_VERSION_FLOORS (space- or comma-separated
# minimum versions), e.g. NODE_VERSION_FLOORS="22.23.4 24.22.1 26.12.1".
#
# Default floor: CVE-2026-111497 (Brotli decoder out-of-bounds write), fixed in
# 22.23.4, 24.22.1 and 26.12.1; Node.js 20 and older are end of life.
# https://nodejs.org/en/blog/vulnerability/october-2026-security-releases
set -euo pipefail

ON_FAIL="${NODE_VERSION_ON_FAIL:-error}"

# problem <exit code> <message>: report, then stop the check.
problem() {
  if [[ "$ON_FAIL" == "warn" ]]; then
    echo "::warning::$2"
    exit 0
  fi
  echo "::error::$2"
  exit "$1"
}

DEFAULT_FLOORS="22.23.4 24.22.1 26.12.1"
FLOORS="${NODE_VERSION_FLOORS:-$DEFAULT_FLOORS}"
FLOORS="${FLOORS//,/ }"
read -r -a FLOOR_LIST <<<"$FLOORS"
FLOORS="${FLOOR_LIST[*]:-}"

usage() {
  echo "usage: $0 --image <image> | --version <vX.Y.Z>" >&2
  exit 2
}

# Prints "major minor patch" for "v22.23.4" / "22.23.4", or fails.
parse() {
  local v="${1#v}"
  if [[ ! "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    return 1
  fi
  echo "$((10#${BASH_REMATCH[1]})) $((10#${BASH_REMATCH[2]})) $((10#${BASH_REMATCH[3]}))"
}

# Validate the floor table once, and find its oldest and newest major lines.
MIN_MAJOR=""
MAX_MAJOR=""
for f in $FLOORS; do
  if ! parts=$(parse "$f"); then
    problem 2 "Invalid entry '$f' in the Node.js version floor table (want X.Y.Z)."
  fi
  read -r fmaj _ _ <<<"$parts"
  if [[ -z "$MIN_MAJOR" || "$fmaj" -lt "$MIN_MAJOR" ]]; then MIN_MAJOR="$fmaj"; fi
  if [[ -z "$MAX_MAJOR" || "$fmaj" -gt "$MAX_MAJOR" ]]; then MAX_MAJOR="$fmaj"; fi
done
if [[ -z "$MIN_MAJOR" ]]; then
  problem 2 "The Node.js version floor table is empty."
fi

fail() {
  problem 1 "Node.js $1 is below the security floor: $2 Use Node.js ${FLOORS// /, } or newer within its line, then rebuild."
}

check_version() {
  local raw="$1" parts maj min pat f fparts fmaj fmin fpat
  if ! parts=$(parse "$raw"); then
    problem 2 "Could not read a Node.js version from '$raw'."
  fi
  read -r maj min pat <<<"$parts"

  if [[ "$maj" -gt "$MAX_MAJOR" ]]; then
    echo "Node.js v$maj.$min.$pat: OK (release line newer than the floor table)."
    return 0
  fi
  if [[ "$maj" -lt "$MIN_MAJOR" ]]; then
    fail "v$maj.$min.$pat" "Node.js $maj is end of life and gets no security fixes."
  fi
  for f in $FLOORS; do
    fparts=$(parse "$f")
    read -r fmaj fmin fpat <<<"$fparts"
    [[ "$fmaj" -eq "$maj" ]] || continue
    if (( min > fmin || (min == fmin && pat >= fpat) )); then
      echo "Node.js v$maj.$min.$pat: OK (floor for $maj.x is $f)."
      return 0
    fi
    fail "v$maj.$min.$pat" "it is below $f, the first $maj.x release with the security fix."
  done
  fail "v$maj.$min.$pat" "the Node.js $maj line is end of life or not a supported release line."
}

check_image() {
  local image="$1" out rc entry
  # No network, no inherited NODE_OPTIONS: only the version is read.
  set +e
  out=$(docker run --rm --pull never --network none --env NODE_OPTIONS= --entrypoint node "$image" -v 2>&1)
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    if [[ $rc -eq 126 || $rc -eq 127 ]] || grep -qiE 'executable file not found|no such file or directory' <<<"$out"; then
      # node is not on PATH. Distroless Node images run node as the entrypoint
      # (e.g. /nodejs/bin/node), so try that before deciding there is no Node.
      entry=$(docker image inspect --format '{{if .Config.Entrypoint}}{{index .Config.Entrypoint 0}}{{end}}' "$image" 2>/dev/null || true)
      if [[ "$entry" == */node || "$entry" == node ]]; then
        set +e
        out=$(docker run --rm --pull never --network none --env NODE_OPTIONS= --entrypoint "$entry" "$image" -v 2>&1)
        rc=$?
        set -e
      fi
      if [[ $rc -ne 0 ]]; then
        echo "No Node.js in $image: skipping the Node.js version check."
        return 0
      fi
    else
      echo "$out"
      problem 2 "Could not run 'node -v' in $image (exit $rc); output above. Set node-version-check: false to skip this check."
    fi
  fi
  out=$(tail -n1 <<<"$out" | tr -d '[:space:]')
  echo "Image $image has Node.js $out."
  check_version "$out"
}

[[ $# -eq 2 ]] || usage
case "$1" in
  --image) check_image "$2" ;;
  --version) check_version "$2" ;;
  *) usage ;;
esac
