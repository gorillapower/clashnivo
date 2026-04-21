#!/bin/bash
# Epic 3c — rule-provider emitter.
#
# Reads every enabled `rule_provider` UCI section and merges it into the
# active config's `rule-providers:` block. Must run before
# clashnivo_yml_rules_change.sh so that script's path normalization + GitHub
# CDN rewrites apply to our injected providers too.
#
# Invoked from init.d Stage 5; takes the target YAML path as $1 (matches the
# calling convention used by yml_groups_set.sh / yml_rules_change.sh).
. /lib/functions.sh
. /usr/share/clashnivo/ruby.sh
. /usr/share/clashnivo/log.sh
. /usr/share/clashnivo/uci.sh

set_lock() {
   exec 889>"/tmp/lock/clashnivo_rule_provider_set.lock" 2>/dev/null
   flock -x 889 2>/dev/null
}

del_lock() {
   flock -u 889 2>/dev/null
   rm -rf "/tmp/lock/clashnivo_rule_provider_set.lock"
}

set_lock

FRAGMENT="/tmp/yaml_rule_providers.yaml"
CONFIG_FILE="$1"
CONFIG_NAME=$(echo "$CONFIG_FILE" | awk -F '/' '{print $5}' 2>/dev/null)

if [ -z "$CONFIG_FILE" ]; then
   CONFIG_FILE=$(uci_get_config "config_path")
   CONFIG_NAME=$(echo "$CONFIG_FILE" | awk -F '/' '{print $5}' 2>/dev/null)
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
   del_lock
   exit 0
fi

# ------------------------------------------------------------------
# Emit one entry under `rule-providers:` for a single UCI section.
# ------------------------------------------------------------------
yml_rule_provider_set()
{
   local section="$1"
   local enabled config name type behavior format url path interval size_limit proxy
   config_get_bool "enabled" "$section" "enabled" "1"
   config_get "config"     "$section" "config"     ""
   config_get "name"       "$section" "name"       ""
   config_get "type"       "$section" "type"       "http"
   config_get "behavior"   "$section" "behavior"   "classical"
   config_get "format"     "$section" "format"     "yaml"
   config_get "url"        "$section" "url"        ""
   config_get "path"       "$section" "path"       ""
   config_get "interval"   "$section" "interval"   "86400"
   config_get "size_limit" "$section" "size_limit" "0"
   config_get "proxy"      "$section" "proxy"      ""

   if [ "$enabled" = "0" ]; then return; fi
   if [ -z "$name" ]; then return; fi

   if [ -n "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ]; then
      return
   fi

   case "$type" in
      http)
         if [ -z "$url" ]; then
            LOG_WARN "Skipping rule-provider [$name]: type=http but no URL set"
            return
         fi
         ;;
      file)
         if [ -z "$path" ] || [ ! -f "/etc/clashnivo/rule_provider/$path" ]; then
            LOG_WARN "Skipping rule-provider [$name]: type=file but source missing"
            return
         fi
         ;;
      *)
         LOG_WARN "Skipping rule-provider [$name]: unknown type [$type]"
         return
         ;;
   esac

   LOG_OUT "Start Writing [$CONFIG_NAME - $type - $name] Rule Provider To Config File..."

   echo "  $name:" >>"$FRAGMENT"
   echo "    type: $type" >>"$FRAGMENT"
   echo "    behavior: $behavior" >>"$FRAGMENT"
   echo "    format: $format" >>"$FRAGMENT"

   if [ "$type" = "http" ]; then
      echo "    url: \"$url\"" >>"$FRAGMENT"
      echo "    interval: $interval" >>"$FRAGMENT"
      [ -n "$size_limit" ] && [ "$size_limit" != "0" ] && \
         echo "    size-limit: $size_limit" >>"$FRAGMENT"
      if [ -n "$path" ]; then
         echo "    path: \"./rule_provider/$path\"" >>"$FRAGMENT"
      else
         echo "    path: \"./rule_provider/$name\"" >>"$FRAGMENT"
      fi
   else
      echo "    path: \"./rule_provider/$path\"" >>"$FRAGMENT"
   fi

   [ -n "$proxy" ] && echo "    proxy: \"$proxy\"" >>"$FRAGMENT"
}

echo "rule-providers:" >"$FRAGMENT"
config_load "clashnivo"
config_foreach yml_rule_provider_set "rule_provider"

# Bail if no providers were emitted (only the header line remains).
if [ "$(wc -l <"$FRAGMENT")" -le 1 ]; then
   rm -f "$FRAGMENT"
   del_lock
   exit 0
fi

ruby_merge "$CONFIG_FILE" "['rule-providers']" "$FRAGMENT" "['rule-providers']"
rm -f "$FRAGMENT"

del_lock
