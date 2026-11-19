#!/bin/bash
# Host-level mitigation for the Linux-kernel half of "nginx2root" (disclosed 2026-11-18).
#
# The nginx2root chain turns remote code execution as the nginx worker (CVE-2026-123007,
# fixed by upgrading nginx) into root on the HOST -- including from inside a Docker
# container -- using a separate use-after-free in the Linux kernel's SCTP code. As of
# 2026-11-18 that kernel bug has no CVE and no patch, so upgrading nginx alone does not
# close the root-escalation path. The published mitigation is to stop the sctp kernel
# module from loading on hosts that do not use SCTP (these hosts do not).
#
# This script is idempotent and safe to run on every deploy. It:
#   1. writes /etc/modprobe.d/disable-sctp.conf (blocks module loading, including the
#      automatic load triggered by the first SCTP socket)
#   2. unloads the sctp module if it is currently loaded and unused
#   3. reports what it cannot fix: SCTP built into the kernel, or a pending reboot
#
# Usage:  ./deploy/harden-host.sh      (as root, or as a user with passwordless sudo)
# Exit:   0  mitigation in place
#         1  could not be applied (no privileges / write failure) -- see output
#
# Once a patched kernel is released: `sudo apt-get update && sudo apt-get upgrade`, reboot,
# and confirm with `uname -r`. See docs/NGINX2ROOT.md.

set -u

CONF_FILE="/etc/modprobe.d/disable-sctp.conf"

DESIRED=$(cat <<'CONF'
# Managed by deploy/harden-host.sh (nginx2root mitigation, Nov 2026).
# A use-after-free in the Linux SCTP code (no CVE / no kernel patch as of 2026-11-18) is
# chained with nginx CVE-2026-123007 to reach root on the host, including from a container.
# Nothing on this host uses SCTP, so block the module from ever loading.
install sctp /bin/false
blacklist sctp
CONF
)

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

echo "Host hardening: blocking the SCTP kernel module (nginx2root)"

if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo > /dev/null 2>&1 || ! sudo -n true 2> /dev/null; then
        echo "WARNING: root or passwordless sudo is required to block the SCTP kernel module."
        echo "         Run this on the server instead: sudo ./deploy/harden-host.sh"
        exit 1
    fi
fi

# 1. Block module loading (only rewrite the file if it differs).
if [ -f "$CONF_FILE" ] && [ "$(cat "$CONF_FILE" 2> /dev/null)" = "$DESIRED" ]; then
    echo "SCTP module block already in place ($CONF_FILE)"
else
    if ! as_root mkdir -p "$(dirname "$CONF_FILE")" ||
       ! printf '%s\n' "$DESIRED" | as_root tee "$CONF_FILE" > /dev/null; then
        echo "ERROR: could not write $CONF_FILE"
        exit 1
    fi
    echo "SCTP module block written to $CONF_FILE"
fi

# 2. Unload the module if something already loaded it.
if as_root lsmod 2> /dev/null | awk '{print $1}' | grep -qx sctp; then
    if as_root rmmod sctp 2> /dev/null; then
        echo "Unloaded the sctp kernel module"
    else
        echo "WARNING: the sctp module is loaded and in use, so it could not be unloaded."
        echo "         It stays loaded until the next reboot; after that the block keeps it out."
    fi
fi

# 3. Report what this mitigation cannot cover.
KERNEL=$(uname -r)
if grep -qE '(^|/)sctp\.ko' "/lib/modules/$KERNEL/modules.builtin" 2> /dev/null; then
    echo "WARNING: SCTP is compiled into kernel $KERNEL; blocking module loading cannot disable it."
    echo "         Apply the vendor kernel fix when it is released (see docs/NGINX2ROOT.md)."
fi

if as_root modprobe -n -v sctp 2>&1 | grep -q '/bin/false'; then
    echo "Verified: 'modprobe sctp' is blocked"
else
    echo "WARNING: could not verify the block with 'modprobe -n -v sctp'"
fi

if [ -f /var/run/reboot-required ]; then
    echo "NOTE: a reboot is pending to finish applying installed updates (e.g. a new kernel)."
fi
echo "Running kernel: $KERNEL"
exit 0
