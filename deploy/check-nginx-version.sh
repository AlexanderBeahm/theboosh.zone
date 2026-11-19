#!/bin/bash
# Verify that nginx contains the fixes for "nginx2root" (CVE-2026-123007 and related,
# disclosed 2026-11-18).
#
# Fixed in nginx mainline >= 1.31.9 and stable >= 1.30.7. Every other release line is
# vulnerable (no fix exists for 1.29.x and older).
#
# Usage:
#   check-nginx-version.sh <compose-file> [service]   Check the running container
#   check-nginx-version.sh --version <x.y.z>          Evaluate a version string
#
# Exit codes (deploy.sh relies on these being distinct):
#   0  patched
#   1  VULNERABLE version detected
#   2  could not determine the version (nginx not running, docker unavailable, ...)
#
# Deliberately no `set -e`: every path must end in one of the exit codes above.

MIN_MAINLINE="1.31.9"
MIN_STABLE="1.30.7"

# ver_ge A B: succeeds when dotted numeric version A >= B (compares three fields).
ver_ge() {
    local IFS=.
    local -a a b
    local i x y
    read -ra a <<< "$1"
    read -ra b <<< "$2"
    for i in 0 1 2; do
        x=$((10#${a[i]:-0}))
        y=$((10#${b[i]:-0}))
        if (( x > y )); then return 0; fi
        if (( x < y )); then return 1; fi
    done
    return 0
}

# is_patched VERSION: mainline >= MIN_MAINLINE, or the 1.30.x stable line >= MIN_STABLE.
is_patched() {
    if ver_ge "$1" "$MIN_MAINLINE"; then
        return 0
    fi
    case $1 in
        1.30.*) ver_ge "$1" "$MIN_STABLE" ;;
        *) return 1 ;;
    esac
}

# query_version COMPOSE_FILE SERVICE: print the nginx version running in that service.
# Retries briefly because this runs right after `docker compose up -d`. stdin is
# redirected so `exec` can never swallow the rest of a script being fed through stdin.
query_version() {
    local out attempt
    for attempt in 1 2 3; do
        if out=$(docker compose -f "$1" exec -T "$2" nginx -v 2>&1 < /dev/null); then
            printf '%s\n' "$out" | sed -n 's|.*nginx/\([0-9][0-9.]*\).*|\1|p' | head -n 1
            return 0
        fi
        if [ "$attempt" -lt 3 ]; then sleep 3; fi
    done
    return 1
}

if [ "${1:-}" = "--version" ]; then
    VERSION=${2:-}
elif [ -n "${1:-}" ]; then
    SERVICE=${2:-nginx}
    VERSION=$(query_version "$1" "$SERVICE")
    if [ -z "$VERSION" ]; then
        echo "WARNING: could not determine the running nginx version (is the '$SERVICE' service running?)"
        exit 2
    fi
else
    echo "Usage: $0 <compose-file> [service] | --version <x.y.z>" >&2
    exit 2
fi

# Validate before doing any arithmetic on it.
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "WARNING: unrecognised nginx version string: '$VERSION'"
    exit 2
fi

if is_patched "$VERSION"; then
    echo "OK: nginx $VERSION includes the nginx2root fixes (needs >= $MIN_MAINLINE mainline or >= $MIN_STABLE stable)"
    exit 0
fi

echo "ERROR: nginx $VERSION is VULNERABLE to nginx2root (CVE-2026-123007 and related)."
echo "       Fixed in nginx >= $MIN_MAINLINE (mainline) or >= $MIN_STABLE (stable)."
exit 1
