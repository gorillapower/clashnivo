#!/bin/bash
# Mihomo core version checker for Clash Nivo. Fetches the upstream tag from
# MetaCubeX/mihomo's `version.txt` asset, caches it to /tmp/mihomo_last_version
# (the path init.d already expects), and prints a JSON summary of
# installed-vs-latest-vs-arch to stdout for the LuCI controller.
#
# Usage: clashnivo_version.sh [github_address_mod_override]
. /lib/functions.sh
. /usr/share/clashnivo/uci.sh

set_lock() {
   mkdir -p /tmp/lock 2>/dev/null
   exec 869>"/tmp/lock/clashnivo_version.lock" 2>/dev/null
   flock -x 869 2>/dev/null
}

del_lock() {
   flock -u 869 2>/dev/null
   rm -rf "/tmp/lock/clashnivo_version.lock" 2>/dev/null
}

set_lock

VERSION_CACHE="/tmp/mihomo_last_version"

github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
if [ -n "$1" ]; then
   github_address_mod="$1"
fi

small_flash_memory=$(uci_get_config "small_flash_memory")
if [ "$small_flash_memory" = "1" ]; then
   core_path="/tmp/etc/clashnivo/core/mihomo"
else
   core_path="/etc/clashnivo/core/mihomo"
fi

CORE_CV=""
if [ -x "$core_path" ]; then
   CORE_CV=$("$core_path" -v 2>/dev/null | awk '{print $3}' | head -1)
fi

LATEST_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt"
if [ "$github_address_mod" != "0" ]; then
   LATEST_URL="${github_address_mod}${LATEST_URL}"
fi

CORE_LV=$(curl -sSL --connect-timeout 10 --max-time 30 "$LATEST_URL" 2>/dev/null | tr -d ' \r\n')

if [ -n "$CORE_LV" ]; then
   echo "$CORE_LV" > "$VERSION_CACHE"
fi

ARCH=$(uci_get_config "core_version")

installed="${CORE_CV:-}"
latest="${CORE_LV:-}"
arch="${ARCH:-}"
if [ "$arch" = "0" ]; then arch=""; fi

update_available="false"
if [ -n "$installed" ] && [ -n "$latest" ] && [ "$installed" != "$latest" ]; then
   update_available="true"
elif [ -z "$installed" ] && [ -n "$latest" ]; then
   update_available="true"
fi

printf '{"installed":"%s","latest":"%s","arch":"%s","update_available":%s}\n' \
   "$installed" "$latest" "$arch" "$update_available"

del_lock
exit 0
