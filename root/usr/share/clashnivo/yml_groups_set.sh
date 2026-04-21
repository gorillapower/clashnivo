#!/bin/bash
# Forked from OpenClash (Copyright (c) 2019-2026 vernesong). Major rewrite:
# every group emits `include-all-proxies: true` instead of per-proxy assignment,
# and the new `exclude_filter` UCI key maps to Mihomo's `exclude-filter:`.
. /lib/functions.sh
. /usr/share/clashnivo/log.sh
. /usr/share/clashnivo/uci.sh

set_lock() {
   exec 887>"/tmp/lock/clashnivo_groups_set.lock" 2>/dev/null
   flock -x 887 2>/dev/null
}

del_lock() {
   flock -u 887 2>/dev/null
   rm -rf "/tmp/lock/clashnivo_groups_set.lock"
}

set_lock
GROUP_FILE="/tmp/yaml_groups.yaml"
CFG_FILE="/etc/config/clashnivo"
CONFIG_FILE=$(uci_get_config "config_path")
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UPDATE_CONFIG_FILE=$1
UPDATE_CONFIG_NAME=$(echo "$UPDATE_CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)

if [ ! -z "$UPDATE_CONFIG_FILE" ]; then
   CONFIG_FILE="$UPDATE_CONFIG_FILE"
   CONFIG_NAME="$UPDATE_CONFIG_NAME"
fi

if [ -z "$CONFIG_FILE" ]; then
   for file_name in /etc/clashnivo/config/*
   do
      if [ -f "$file_name" ]; then
         CONFIG_FILE=$file_name
         CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
         break
      fi
   done
fi

if [ -z "$CONFIG_NAME" ]; then
   CONFIG_FILE="/etc/clashnivo/config/config.yaml"
   CONFIG_NAME="config.yaml"
fi

# Emit one entry under `proxies:` for a member of `other_group`. Values
# matching a utility keyword (DIRECT / REJECT / REJECT-DROP / PASS / GLOBAL)
# are written as-is; anything else is treated as a literal group name.
emit_other_group()
{
   local value="$1"
   [ -z "$value" ] && return

   case "$value" in
      DIRECT|REJECT|REJECT-DROP|PASS|GLOBAL)
         has_proxies_block=1
         echo "      - $value" >>$GROUP_FILE
         ;;
      *)
         has_proxies_block=1
         echo "      - $value" >>$GROUP_FILE
         ;;
   esac
}

# Create the proxy-group entry for one UCI `groups` section.
yml_groups_set()
{
   local section="$1"
   local enabled config type name disable_udp strategy test_url test_interval tolerance filter exclude_filter other_parameters icon interface_name routing_mark
   config_get_bool "enabled" "$section" "enabled" "1"
   config_get "config" "$section" "config" ""
   config_get "type" "$section" "type" ""
   config_get "name" "$section" "name" ""
   config_get "disable_udp" "$section" "disable_udp" ""
   config_get "strategy" "$section" "strategy" ""
   config_get "test_url" "$section" "test_url" ""
   config_get "test_interval" "$section" "test_interval" ""
   config_get "tolerance" "$section" "tolerance" ""
   config_get "filter" "$section" "filter" ""
   config_get "exclude_filter" "$section" "exclude_filter" ""
   config_get "interface_name" "$section" "interface_name" ""
   config_get "routing_mark" "$section" "routing_mark" ""
   config_get "other_parameters" "$section" "other_parameters" ""
   config_get "icon" "$section" "icon" ""

   if [ "$enabled" = "0" ]; then
      return
   fi

   if [ -n "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ]; then
      return
   fi

   if [ -z "$type" ]; then
      return
   fi

   if [ -z "$name" ]; then
      return
   fi

   LOG_OUT "Start Writing [$CONFIG_NAME - $type - $name] Group To Config File..."

   echo "  - name: $name" >>$GROUP_FILE
   echo "    type: $type" >>$GROUP_FILE
   echo "    include-all-proxies: true" >>$GROUP_FILE

   has_proxies_block=0
   echo "    proxies:" >>$GROUP_FILE
   config_list_foreach "$section" "other_group" emit_other_group
   if [ "$has_proxies_block" -eq 0 ]; then
      # Drop the empty `proxies:` header we just wrote.
      sed -i '$d' $GROUP_FILE 2>/dev/null
   fi

   [ -n "$filter" ] && {
      echo "    filter: \"$filter\"" >>$GROUP_FILE
   }
   [ -n "$exclude_filter" ] && {
      echo "    exclude-filter: \"$exclude_filter\"" >>$GROUP_FILE
   }

   if [ "$type" = "load-balance" ]; then
      [ -n "$strategy" ] && {
         echo "    strategy: $strategy" >>$GROUP_FILE
      }
   fi

   [ -n "$disable_udp" ] && {
      echo "    disable-udp: $disable_udp" >>$GROUP_FILE
   }

   [ -n "$test_url" ] && {
      echo "    url: $test_url" >>$GROUP_FILE
   }
   [ -n "$test_interval" ] && {
      echo "    interval: \"$test_interval\"" >>$GROUP_FILE
   }
   [ -n "$tolerance" ] && {
      echo "    tolerance: \"$tolerance\"" >>$GROUP_FILE
   }
   [ -n "$interface_name" ] && {
      echo "    interface-name: \"$interface_name\"" >>$GROUP_FILE
   }
   [ -n "$routing_mark" ] && {
      echo "    routing-mark: \"$routing_mark\"" >>$GROUP_FILE
   }

   if [ -n "$icon" ]; then
      echo "    icon: $icon" >> "$GROUP_FILE"
   fi

   if [ -n "$other_parameters" ]; then
      echo -e "$other_parameters" >> "$GROUP_FILE"
   fi
}

echo "proxy-groups:" >$GROUP_FILE
config_load "clashnivo"
config_foreach yml_groups_set "groups"
sed -i "s/#delete_//g" "$CONFIG_FILE" 2>/dev/null

/usr/share/clashnivo/yml_proxys_set.sh "$CONFIG_FILE" >/dev/null 2>&1
del_lock
