#!/bin/sh
# Forked from OpenClash (Copyright (c) 2019-2026 vernesong). Pruned:
# Ruby `skip_proxies_address`, streaming-unlock block, config auto-update
# tick, and IPv6 localnetwork refresh removed.
. /usr/share/clashnivo/log.sh
. /lib/functions.sh
. /usr/share/clashnivo/clashnivo_ps.sh
. /usr/share/clashnivo/uci.sh

LOG_FILE="/tmp/clashnivo.log"
FIREWALL_RELOAD=0
MAX_FIREWALL_RELOAD=3
FW4=$(command -v fw4)

while :;
do
   CONFIG_FILE="/etc/clashnivo/$(uci_get_config "config_path" |awk -F '/' '{print $5}' 2>/dev/null)"
   enable_redirect_dns=$(uci_get_config "enable_redirect_dns")
   dns_port=$(uci_get_config "dns_port")
   disable_masq_cache=$(uci_get_config "disable_masq_cache")
   log_size=$(uci_get_config "log_size" || echo 1024)
   upnp_lease_file=$(uci -q get upnpd.config.upnp_lease_file)

   # Wait for core start to complete.
   while ( [ -n "$(unify_ps_pids "/etc/init.d/clashnivo")" ] )
   do
      sleep 1
   done >/dev/null 2>&1

   # Check the clashnivo service status.
   if ! ubus call service list '{"name":"clashnivo"}' 2>/dev/null | jsonfilter -e '@.clashnivo.instances.*.running' | grep -q 'true'; then
      uci -q set clashnivo.config.enable=0
      uci -q commit clashnivo
      /etc/init.d/clashnivo stop >/dev/null 2>&1
      exit 0
   fi

   # Log rotation.
   LOGSIZE=$(ls -l /tmp/clashnivo.log 2>/dev/null | awk '{print int($5/1024)}')
   if [ "$LOGSIZE" -gt "$log_size" ]; then
      : > /tmp/clashnivo.log
      LOG_WATCHDOG "Log Size Limit, Clean Up All Log Records..."
   fi

   # Firewall rule-order sanity check.
   if [ "$FIREWALL_RELOAD" -le "$MAX_FIREWALL_RELOAD" ]; then
      if [ -z "$FW4" ]; then
         nat_last_line=$(iptables -t nat -nL PREROUTING --line-number 2>/dev/null | awk 'END {print $1}')
         man_last_line=$(iptables -t mangle -nL PREROUTING --line-number 2>/dev/null | awk 'END {print $1}')
         nat_op_line=$(iptables -t nat -nL PREROUTING --line-number 2>/dev/null | grep -E "clashnivo|CLASHNIVO" | grep -Ev "DNS|dns" | awk '{print $1}' | tail -1)
         man_op_line=$(iptables -t mangle -nL PREROUTING --line-number 2>/dev/null | grep -E "clashnivo|CLASHNIVO" | grep -Ev "DNS|dns" | awk '{print $1}' | tail -1)
      else
         nat_last_line=$(nft -a list chain inet fw4 dstnat 2>/dev/null | grep "# handle" | awk -F '# handle ' '{print $2}' | tail -1)
         man_last_line=$(nft -a list chain inet fw4 mangle_prerouting 2>/dev/null | grep "# handle" | awk -F '# handle ' '{print $2}' | tail -1)
         nat_op_line=$(nft -a list chain inet fw4 dstnat 2>/dev/null | grep -E "clashnivo|CLASHNIVO" | grep -Ev "DNS|dns" | grep "# handle" | awk -F '# handle ' '{print $2}' | tail -1)
         man_op_line=$(nft -a list chain inet fw4 mangle_prerouting 2>/dev/null | grep -E "clashnivo|CLASHNIVO" | grep -Ev "DNS|dns" | grep "# handle" | awk -F '# handle ' '{print $2}' | tail -1)
      fi

      if ([ "$nat_last_line" != "$nat_op_line" ] && [ -n "$nat_op_line" ]) || ([ "$man_last_line" != "$man_op_line" ] && [ -n "$man_op_line" ]); then
         LOG_WATCHDOG "Setting Firewall For Rules Order..."
         /etc/init.d/clashnivo reload "firewall"
         FIREWALL_RELOAD=$((FIREWALL_RELOAD + 1))
      elif [ -n "$(ip tuntap list |grep utun)" ] && [ -z "$(ip route list table 354)" ]; then
         LOG_WATCHDOG "Setting Firewall For IP Rules Table Recreate..."
         /etc/init.d/clashnivo reload "firewall"
         FIREWALL_RELOAD=$((FIREWALL_RELOAD + 1))
      else
         FIREWALL_RELOAD=0
      fi
   fi

   # Localnetwork set refresh (IPv4 only).
   wan_ip4s=$(/usr/share/clashnivo/clashnivo_get_network.lua "wanip" 2>/dev/null)
   lan_ip4s=$(/usr/share/clashnivo/clashnivo_get_network.lua "lan_cidr" 2>/dev/null)
   if [ -n "$FW4" ]; then
      if [ -n "$wan_ip4s" ]; then
         for wan_ip4 in $wan_ip4s; do
            nft add element inet fw4 clashnivo_localnetwork { "$wan_ip4" } 2>/dev/null
         done
      fi
      if [ -n "$lan_ip4s" ]; then
         for lan_ip4 in $lan_ip4s; do
            nft add element inet fw4 clashnivo_localnetwork { "$lan_ip4" } 2>/dev/null
         done
      fi
   else
      if [ -n "$wan_ip4s" ]; then
         for wan_ip4 in $wan_ip4s; do
            ipset add clashnivo_localnetwork "$wan_ip4" 2>/dev/null
         done
      fi
      if [ -n "$lan_ip4s" ]; then
         for lan_ip4 in $lan_ip4s; do
            ipset add clashnivo_localnetwork "$lan_ip4" 2>/dev/null
         done
      fi
   fi

   # UPnP lease sync.
   if [ -f "$upnp_lease_file" ]; then
      # delete stale entries
      if [ -n "$FW4" ]; then
         for i in $(nft list chain inet fw4 clashnivo_upnp 2>/dev/null | grep "return")
         do
            upnp_ip=$(echo "$i" |awk -F 'ip saddr ' '{print $2}' |awk  '{print $1}')
            upnp_dp=$(echo "$i" |awk -F 'sport ' '{print $2}' |awk  '{print $1}')
            upnp_type=$(echo "$i" |awk -F 'sport ' '{print $1}' |awk  '{print $4}' |tr '[a-z]' '[A-Z]')
            if [ -n "$upnp_ip" ] && [ -n "$upnp_dp" ] && [ -n "$upnp_type" ]; then
               if [ -z "$(cat "$upnp_lease_file" |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                  handle=$(nft -a list chain inet fw4 clashnivo_upnp |grep "$i" |awk -F '# handle ' '{print$2}')
                  nft delete rule inet fw4 clashnivo_upnp handle ${handle}
               fi
            fi
         done >/dev/null 2>&1
      else
         for i in $(iptables -t mangle -nL clashnivo_upnp 2>/dev/null | grep "RETURN")
         do
            upnp_ip=$(echo "$i" |awk '{print $4}')
            upnp_dp=$(echo "$i" |awk -F 'spt:' '{print $2}')
            upnp_type=$(echo "$i" |awk '{print $2}' |tr '[a-z]' '[A-Z]')
            if [ -n "$upnp_ip" ] && [ -n "$upnp_dp" ] && [ -n "$upnp_type" ]; then
               if [ -z "$(cat "$upnp_lease_file" |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                  iptables -t mangle -D clashnivo_upnp -p "$upnp_type" -s "$upnp_ip" --sport "$upnp_dp" -j RETURN 2>/dev/null
               fi
            fi
         done >/dev/null 2>&1
      fi
      # add new leases
      if [ -s "$upnp_lease_file" ] && { [ -n "$(iptables --line-numbers -t nat -xnvL clashnivo_upnp 2>/dev/null)" ] || [ -n "$(nft list chain inet fw4 clashnivo_upnp 2>/dev/null)" ]; }; then
         cat "$upnp_lease_file" | while read -r line
         do
            if [ -n "$line" ]; then
               upnp_ip=$(echo "$line" |awk -F ':' '{print $3}')
               upnp_dp=$(echo "$line" |awk -F ':' '{print $4}')
               upnp_type=$(echo "$line" |awk -F ':' '{print $1}' |tr '[A-Z]' '[a-z]')
               if [ -n "$upnp_ip" ] && [ -n "$upnp_dp" ] && [ -n "$upnp_type" ]; then
                  if [ -n "$FW4" ]; then
                     if [ -z "$(nft list chain inet fw4 clashnivo_upnp |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                        nft add rule inet fw4 clashnivo_upnp ip saddr { "$upnp_ip" } "$upnp_type" sport "$upnp_dp" counter return 2>/dev/null
                     fi
                  else
                     if [ -z "$(iptables -t mangle -nL clashnivo_upnp |grep "$upnp_ip" |grep "$upnp_dp" |grep "$upnp_type")" ]; then
                        iptables -t mangle -A clashnivo_upnp -p "$upnp_type" -s "$upnp_ip" --sport "$upnp_dp" -j RETURN 2>/dev/null
                     fi
                  fi
               fi
            fi
         done >/dev/null 2>&1
      fi
   fi

   # DNS hijack refresh.
   if [ "$enable_redirect_dns" = "1" ]; then
      if [ -z "$(uci -q get dhcp.@dnsmasq[0].server |grep "$dns_port")" ] || [ ! -z "$(uci -q get dhcp.@dnsmasq[0].server |awk -F ' ' '{print $2}')" ]; then
         LOG_WATCHDOG "Force Reset DNS Hijack..."
         uci -q del dhcp.@dnsmasq[-1].server
         uci -q add_list dhcp.@dnsmasq[0].server=127.0.0.1#"$dns_port"
         uci -q delete dhcp.@dnsmasq[0].resolvfile
         uci -q set dhcp.@dnsmasq[0].noresolv=1
         [ "$disable_masq_cache" -eq 1 ] && {
            uci -q set dhcp.@dnsmasq[0].cachesize=0
         }
         uci -q commit dhcp
         /etc/init.d/dnsmasq restart >/dev/null 2>&1
      fi
   fi

   SLOG_CLEAN
   sleep 60
done 2>/dev/null
