#!/bin/bash
# Forked from OpenClash (Copyright (c) 2019-2026 vernesong). Downloads the
# Mihomo binary from MetaCubeX/mihomo releases with SHA256 verification.
. /lib/functions.sh
. /usr/share/clashnivo/log.sh
. /usr/share/clashnivo/uci.sh
. /usr/share/clashnivo/clashnivo_curl.sh
. /usr/share/clashnivo/clashnivo_ps.sh

set_lock() {
   exec 872>"/tmp/lock/clashnivo_core.lock" 2>/dev/null
   flock -x 872 2>/dev/null
}

del_lock() {
   flock -u 872 2>/dev/null
   rm -rf "/tmp/lock/clashnivo_core.lock" 2>/dev/null
}

set_lock
inc_job_counter

restart=0
github_address_mod=$(uci_get_config "github_address_mod" || echo 0)
# $1 (optional) — explicit github_address_mod override from caller.
if [ -n "$1" ]; then
   github_address_mod="$1"
fi
if [ "$github_address_mod" = "0" ]; then
   LOG_TIP "If the download fails, try setting the CDN in Settings > Github Address Modify Options"
fi

small_flash_memory=$(uci_get_config "small_flash_memory")
ARCH=$(uci_get_config "core_version")

if [ -z "$ARCH" ] || [ "$ARCH" = "0" ]; then
   LOG_WARN "No core architecture selected — set core_version in UCI (e.g. linux-arm64) and retry."
   SLOG_CLEAN
   del_lock
   exit 0
fi

# Resolve the latest Mihomo version via GitHub's "latest" redirect.
LATEST_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt"
if [ "$github_address_mod" != "0" ]; then
   LATEST_URL="${github_address_mod}${LATEST_URL}"
fi

CORE_LV=$(curl -sSL --connect-timeout 10 --max-time 30 "$LATEST_URL" 2>/dev/null | tr -d ' \r\n')
if [ -z "$CORE_LV" ]; then
   LOG_ERROR "Mihomo version check failed. Please try again later."
   SLOG_CLEAN
   del_lock
   exit 0
fi

if [ "$small_flash_memory" != "1" ]; then
   core_path="/etc/clashnivo/core/mihomo"
   mkdir -p /etc/clashnivo/core
else
   core_path="/tmp/etc/clashnivo/core/mihomo"
   mkdir -p /tmp/etc/clashnivo/core
fi

CORE_CV=$("$core_path" -v 2>/dev/null | awk '{print $3}' | head -1)
ASSET="mihomo-${ARCH}-${CORE_LV}.gz"
SHA_ASSET="${ASSET}.sha256"
DOWNLOAD_FILE="/tmp/${ASSET}"
SHA_FILE="/tmp/${SHA_ASSET}"
TMP_BIN="/tmp/mihomo"

build_release_url() {
   local asset="$1"
   if [ "$github_address_mod" != "0" ]; then
      echo "${github_address_mod}https://github.com/MetaCubeX/mihomo/releases/download/${CORE_LV}/${asset}"
   else
      echo "https://github.com/MetaCubeX/mihomo/releases/download/${CORE_LV}/${asset}"
   fi
}

if [ "$CORE_CV" != "$CORE_LV" ] || [ ! -x "$core_path" ]; then
   LOG_TIP "Mihomo core downloading (${CORE_LV} / ${ARCH}). If it fails, download and upload manually."

   retry_count=0
   max_retries=3
   while [ "$retry_count" -lt "$max_retries" ]; do
      retry_count=$((retry_count + 1))
      rm -f "$DOWNLOAD_FILE" "$SHA_FILE" "$TMP_BIN" 2>/dev/null

      DOWNLOAD_URL=$(build_release_url "$ASSET")
      SHA_URL=$(build_release_url "$SHA_ASSET")

      SHOW_DOWNLOAD_PROGRESS=1 DOWNLOAD_FILE_CURL "$DOWNLOAD_URL" "$DOWNLOAD_FILE" "$core_path"
      DOWNLOAD_RESULT=$?

      if [ "$DOWNLOAD_RESULT" -eq 2 ]; then
         LOG_TIP "Mihomo core has not been updated, stopping."
         SLOG_CLEAN
         break
      fi

      if [ "$DOWNLOAD_RESULT" -ne 0 ]; then
         if [ "$retry_count" -lt "$max_retries" ]; then
            LOG_ERROR "[$retry_count/$max_retries] Mihomo core download failed, retrying..."
            sleep 2
            continue
         fi
         LOG_ERROR "Mihomo core download failed. Please check the network or try again later."
         SLOG_CLEAN
         break
      fi

      if ! gzip -t "$DOWNLOAD_FILE" >/dev/null 2>&1; then
         if [ "$retry_count" -lt "$max_retries" ]; then
            LOG_ERROR "[$retry_count/$max_retries] Mihomo core archive is corrupt, retrying..."
            sleep 2
            continue
         fi
         LOG_ERROR "Mihomo core archive is corrupt. Please try again later."
         SLOG_CLEAN
         break
      fi

      # SHA256 verification (Mihomo publishes <asset>.sha256 alongside each .gz).
      if curl -sSL --connect-timeout 10 --max-time 30 -o "$SHA_FILE" "$SHA_URL" 2>/dev/null && [ -s "$SHA_FILE" ]; then
         expected=$(awk '{print $1}' "$SHA_FILE" | head -1)
         actual=$(sha256sum "$DOWNLOAD_FILE" 2>/dev/null | awk '{print $1}')
         if [ -n "$expected" ] && [ "$expected" != "$actual" ]; then
            LOG_ERROR "Mihomo core SHA256 mismatch (expected $expected got $actual). Aborting."
            SLOG_CLEAN
            break
         fi
      else
         LOG_WARN "Could not fetch SHA256 for Mihomo core — continuing without checksum verification."
      fi

      extract_ok=true
      gunzip -c "$DOWNLOAD_FILE" > "$TMP_BIN" 2>/dev/null || extract_ok=false
      chmod 0755 "$TMP_BIN" >/dev/null 2>&1 || extract_ok=false
      "$TMP_BIN" -v >/dev/null 2>&1 || extract_ok=false

      if [ "$extract_ok" != "true" ]; then
         if [ "$retry_count" -lt "$max_retries" ]; then
            LOG_ERROR "[$retry_count/$max_retries] Mihomo core extract/validate failed, retrying..."
            rm -f "$TMP_BIN" 2>/dev/null
            sleep 2
            continue
         fi
         LOG_ERROR "Mihomo core extract failed. Check flash space or selected architecture and try again."
         rm -f "$TMP_BIN" 2>/dev/null
         SLOG_CLEAN
         break
      fi

      if mv "$TMP_BIN" "$core_path" 2>/dev/null; then
         LOG_TIP "Mihomo core update successful (${CORE_LV})."
         SLOG_CLEAN
         restart=1
         break
      fi

      if [ "$retry_count" -lt "$max_retries" ]; then
         LOG_ERROR "[$retry_count/$max_retries] Mihomo core install failed, retrying..."
         sleep 2
         continue
      fi
      LOG_ERROR "Mihomo core install failed. Check flash space and try again."
      SLOG_CLEAN
      break
   done
else
   LOG_TIP "Mihomo core is already up to date (${CORE_LV})."
   SLOG_CLEAN
fi

rm -f "$DOWNLOAD_FILE" "$SHA_FILE" "$TMP_BIN" 2>/dev/null
dec_job_counter_and_restart "$restart"
del_lock
