#!/bin/sh
. /lib/functions.sh
. /usr/share/clashnivo/ruby.sh
. /usr/share/clashnivo/log.sh
. /usr/share/clashnivo/uci.sh

set_lock() {
   exec 886>"/tmp/lock/clashnivo_proxies_set.lock" 2>/dev/null
   flock -x 886 2>/dev/null
}

del_lock() {
   flock -u 886 2>/dev/null
   rm -rf "/tmp/lock/clashnivo_proxies_set.lock"
}

SERVER_FILE="/tmp/yaml_servers.yaml"
PROXY_PROVIDER_FILE="/tmp/yaml_provider.yaml"
CONFIG_FILE=$(uci_get_config "config_path")
CONFIG_NAME=$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UPDATE_CONFIG_FILE=$1
UPDATE_CONFIG_NAME=$(echo "$UPDATE_CONFIG_FILE" |awk -F '/' '{print $5}' 2>/dev/null)
UCI_DEL_LIST="uci -q del_list clashnivo.config.new_servers_group"
UCI_ADD_LIST="uci -q add_list clashnivo.config.new_servers_group"
UCI_SET="uci -q set clashnivo.config."
servers_name="/tmp/servers_name.list"
proxy_provider_name="/tmp/provider_name.list"
set_lock

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

# Write proxy-providers to config file
yml_proxy_provider_set()
{
   local section="$1"
   local enabled config type name path provider_filter provider_url provider_interval health_check health_check_url health_check_interval other_parameters
   config_get_bool "enabled" "$section" "enabled" "1"
   config_get "config" "$section" "config" ""
   config_get "type" "$section" "type" ""
   config_get "name" "$section" "name" ""
   config_get "path" "$section" "path" ""
   config_get "provider_filter" "$section" "provider_filter" ""
   config_get "provider_url" "$section" "provider_url" ""
   config_get "provider_interval" "$section" "provider_interval" ""
   config_get "health_check" "$section" "health_check" ""
   config_get "health_check_url" "$section" "health_check_url" ""
   config_get "health_check_interval" "$section" "health_check_interval" ""
   config_get "other_parameters" "$section" "other_parameters" ""

   if [ "$enabled" = "0" ]; then
      return
   fi

   if [ -z "$type" ]; then
      return
   fi

   if [ -z "$name" ]; then
      return
   fi

   if [ "$path" != "./proxy_provider/$name.yaml" ] && [ "$type" = "http" ]; then
      path="./proxy_provider/$name.yaml"
   elif [ -z "$path" ]; then
      return
   fi

   if [ -z "$health_check" ]; then
      return
   fi

   if [ ! -z "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ]; then
      return
   fi

   # Avoid duplicate proxy-providers
   if [ "$config" = "$CONFIG_NAME" ] || [ "$config" = "all" ]; then
      if [ -n "$(grep -w "path: $path" "$PROXY_PROVIDER_FILE" 2>/dev/null)" ]; then
         return
      elif [ "$(grep -w "^$name$" "$proxy_provider_name" |wc -l 2>/dev/null)" -ge 2 ] && [ -z "$(grep -w "path: $path" "$PROXY_PROVIDER_FILE" 2>/dev/null)" ]; then
      	 convert_name=$(echo "$name" |sed 's/\//\\\//g' 2>/dev/null)
         sed -i "1,/^${convert_name}$/{//d}" "$proxy_provider_name" 2>/dev/null
         return
      fi
   fi

   LOG_OUT "Start Writing[$CONFIG_NAME - $type - $name]Proxy-provider To Config File..."
   echo "$name" >> /tmp/Proxy_Provider

cat >> "$PROXY_PROVIDER_FILE" <<-EOF
  $name:
    type: $type
    path: "$path"
EOF
   if [ -n "$provider_filter" ]; then
cat >> "$PROXY_PROVIDER_FILE" <<-EOF
    filter: "$provider_filter"
EOF
   fi
   if [ -n "$provider_url" ]; then
cat >> "$PROXY_PROVIDER_FILE" <<-EOF
    url: "$provider_url"
    interval: $provider_interval
EOF
   fi
cat >> "$PROXY_PROVIDER_FILE" <<-EOF
    health-check:
      enable: $health_check
      url: "$health_check_url"
      interval: $health_check_interval
EOF

#other_parameters
   if [ -n "$other_parameters" ]; then
      echo -e "$other_parameters" >> "$PROXY_PROVIDER_FILE"
   fi
}

set_alpn()
{
   if [ -z "$1" ]; then
      return
   fi
cat >> "$SERVER_FILE" <<-EOF
      - '$1'
EOF
}

set_http_path()
{
   if [ -z "$1" ]; then
      return
   fi
cat >> "$SERVER_FILE" <<-EOF
        - '$1'
EOF
}

set_h2_host()
{
   if [ -z "$1" ]; then
      return
   fi
cat >> "$SERVER_FILE" <<-EOF
        - '$1'
EOF
}

set_ws_headers()
{
   if [ -z "$1" ]; then
      return
   fi
cat >> "$SERVER_FILE" <<-EOF
        $1
EOF
}

# Write server nodes to config file
yml_servers_set()
{

   local section="$1"
   config_get_bool "enabled" "$section" "enabled" "1"
   config_get "config" "$section" "config" ""
   config_get "type" "$section" "type" ""
   config_get "name" "$section" "name" ""
   config_get "server" "$section" "server" ""
   config_get "port" "$section" "port" ""

   if [ "$enabled" = "0" ]; then
      return
   fi

   if [ -z "$type" ]; then
      return
   fi

   if [ -z "$name" ]; then
      return
   fi

   if [ -z "$server" ]; then
      return
   fi

   if [ -z "$port" ]; then
      return
   fi

    if [ "$type" = "ss" ] || [ "$type" = "trojan" ]; then
        config_get "password" "$section" "password" ""
        if [ -z "$password" ]; then
            return
        fi
    fi

   if [ ! -z "$config" ] && [ "$config" != "$CONFIG_NAME" ] && [ "$config" != "all" ]; then
      return
   fi

   # Avoid duplicate nodes
   if [ "$config" = "$CONFIG_NAME" ] || [ "$config" = "all" ]; then
      if [ "$(grep -w "^$name$" "$servers_name" |wc -l 2>/dev/null)" -ge 2 ] && [ -n "$(grep -w "name: \"$name\"" "$SERVER_FILE" 2>/dev/null)" ]; then
         return
      fi
   fi

   if [ "$config" = "$CONFIG_NAME" ] || [ "$config" = "all" ]; then
      if [ -n "$(grep -w "name: \"$name\"" "$SERVER_FILE" 2>/dev/null)" ]; then
         return
      elif [ "$(grep -w "^$name$" "$servers_name" |wc -l 2>/dev/null)" -ge 2 ] && [ -z "$(grep -w "name: \"$name\"" "$SERVER_FILE" 2>/dev/null)" ]; then
      	 convert_name=$(echo "$name" |sed 's/\//\\\//g' 2>/dev/null)
         sed -i "1,/^${convert_name}$/{//d}" "$servers_name" 2>/dev/null
         return
      fi
   fi
   LOG_OUT "Start Writing[$CONFIG_NAME - $type - $name]Proxy To Config File..."

   config_get "dialer_proxy" "$section" "dialer_proxy" ""
   config_get "udp" "$section" "udp" ""
   config_get "skip_cert_verify" "$section" "skip_cert_verify" ""
   config_get "tls" "$section" "tls" ""
   config_get "sni" "$section" "sni" ""
   config_get "alpn" "$section" "alpn" ""
   config_get "fingerprint" "$section" "fingerprint" ""
   config_get "client_fingerprint" "$section" "client_fingerprint" ""
   config_get "ip_version" "$section" "ip_version" ""
   config_get "tfo" "$section" "tfo" ""
   config_get "multiplex" "$section" "multiplex" ""
   config_get "multiplex_protocol" "$section" "multiplex_protocol" ""
   config_get "multiplex_max_connections" "$section" "multiplex_max_connections" ""
   config_get "multiplex_min_streams" "$section" "multiplex_min_streams" ""
   config_get "multiplex_max_streams" "$section" "multiplex_max_streams" ""
   config_get "multiplex_padding" "$section" "multiplex_padding" ""
   config_get "multiplex_statistic" "$section" "multiplex_statistic" ""
   config_get "multiplex_only_tcp" "$section" "multiplex_only_tcp" ""
   config_get "interface_name" "$section" "interface_name" ""
   config_get "routing_mark" "$section" "routing_mark" ""
   config_get "other_parameters" "$section" "other_parameters" ""

   if [ "$client_fingerprint" = "none" ]; then
        client_fingerprint=""
   fi

   if [ "$multiplex" = "false" ]; then
        multiplex=""
   fi

#ss
if [ "$type" = "ss" ]; then
   config_get "cipher" "$section" "cipher" ""
   config_get "obfs" "$section" "obfs" ""
   config_get "host" "$section" "host" ""
   config_get "mux" "$section" "mux" ""
   config_get "custom" "$section" "custom" ""
   config_get "path" "$section" "path" ""
   config_get "obfs_password" "$section" "obfs_password" ""
   config_get "obfs_version_hint" "$section" "obfs_version_hint" ""
   config_get "obfs_restls_script" "$section" "obfs_restls_script" ""
   config_get "udp_over_tcp" "$section" "udp_over_tcp" ""

   if [ "$obfs" != "none" ] && [ -n "$obfs" ]; then
      if [ "$obfs" = "websocket" ]; then
            obfss="plugin: v2ray-plugin"
      elif [ "$obfs" = "shadow-tls" ]; then
            obfss="plugin: shadow-tls"
      elif [ "$obfs" = "restls" ]; then
            obfss="plugin: restls"
      else
            obfss="plugin: obfs"
      fi
   else
      obfss=""
   fi

   if [ ! -z "$path" ]; then
      path="path: \"$path\""
   fi

cat >> "$SERVER_FILE" <<-EOF
  - name: "$name"
    type: $type
    server: "$server"
    port: $port
    cipher: $cipher
    password: "$password"
EOF
    if [ ! -z "$udp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    udp: $udp
EOF
    fi
    if [ ! -z "$udp_over_tcp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    udp-over-tcp: $udp_over_tcp
EOF
    fi
    if [ ! -z "$obfss" ]; then
cat >> "$SERVER_FILE" <<-EOF
    $obfss
    plugin-opts:
EOF
        if [ "$obfs" != "shadow-tls" ] && [ "$obfs" != "restls" ]; then
cat >> "$SERVER_FILE" <<-EOF
      mode: $obfs
EOF
        fi
        if [ ! -z "$host" ]; then
cat >> "$SERVER_FILE" <<-EOF
      host: "$host"
EOF
        fi
        if [  "$obfss" = "plugin: shadow-tls" ]; then
            if [ ! -z "$obfs_password" ]; then
cat >> "$SERVER_FILE" <<-EOF
      password: "$obfs_password"
EOF
            fi
            if [ ! -z "$fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
      fingerprint: "$fingerprint"
EOF
            fi
        fi
        if [  "$obfss" = "plugin: restls" ]; then
            if [ ! -z "$obfs_password" ]; then
cat >> "$SERVER_FILE" <<-EOF
      password: "$obfs_password"
EOF
            fi
            if [ ! -z "$obfs_version_hint" ]; then
cat >> "$SERVER_FILE" <<-EOF
      version-hint: "$obfs_version_hint"
EOF
            fi
            if [ ! -z "$obfs_restls_script" ]; then
cat >> "$SERVER_FILE" <<-EOF
      restls-script: "$obfs_restls_script"
EOF
            fi
        fi
        if [  "$obfss" = "plugin: v2ray-plugin" ]; then
            if [ ! -z "$tls" ]; then
cat >> "$SERVER_FILE" <<-EOF
      tls: $tls
EOF
            fi
            if [ ! -z "$skip_cert_verify" ]; then
cat >> "$SERVER_FILE" <<-EOF
      skip-cert-verify: $skip_cert_verify
EOF
            fi
            if [ ! -z "$path" ]; then
cat >> "$SERVER_FILE" <<-EOF
      $path
EOF
            fi
            if [ ! -z "$mux" ]; then
cat >> "$SERVER_FILE" <<-EOF
      mux: $mux
EOF
            fi
            if [ ! -z "$custom" ]; then
cat >> "$SERVER_FILE" <<-EOF
      headers:
        custom: $custom
EOF
            fi
            if [ ! -z "$fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
      fingerprint: "$fingerprint"
EOF
            fi
        fi
    fi
fi

#vmess
if [ "$type" = "vmess" ]; then
   config_get "uuid" "$section" "uuid" ""
   config_get "alterId" "$section" "alterId" ""
   config_get "securitys" "$section" "securitys" ""
   config_get "xudp" "$section" "xudp" ""
   config_get "packet_encoding" "$section" "packet_encoding" ""
   config_get "global_padding" "$section" "global_padding" ""
   config_get "authenticated_length" "$section" "authenticated_length" ""
   config_get "servername" "$section" "servername" ""
   config_get "obfs_vmess" "$section" "obfs_vmess" ""
   config_get "custom" "$section" "custom" ""
   config_get "path" "$section" "path" ""
   config_get "ws_opts_path" "$section" "ws_opts_path" ""
   config_get "ws_opts_headers" "$section" "ws_opts_headers" ""
   config_get "max_early_data" "$section" "max_early_data" ""
   config_get "early_data_header_name" "$section" "early_data_header_name" ""
   config_get "http_path" "$section" "http_path" ""
   config_get "keep_alive" "$section" "keep_alive" ""
   config_get "h2_path" "$section" "h2_path" ""
   config_get "h2_host" "$section" "h2_host" ""
   config_get "grpc_service_name" "$section" "grpc_service_name" ""

   if [ "$obfs_vmess" = "websocket" ]; then
      obfs_vmess="network: ws"
   fi
   if [ "$obfs_vmess" = "http" ]; then
      obfs_vmess="network: http"
   fi
   if [ "$obfs_vmess" = "h2" ]; then
      obfs_vmess="network: h2"
   fi
   if [ "$obfs_vmess" = "grpc" ]; then
      obfs_vmess="network: grpc"
   fi

   if [ ! -z "$custom" ]; then
      custom="Host: \"$custom\""
   fi

   if [ ! -z "$path" ] && [ "$obfs_vmess" = "network: ws" ]; then
      path="ws-path: \"$path\""
   fi

cat >> "$SERVER_FILE" <<-EOF
  - name: "$name"
    type: $type
    server: "$server"
    port: $port
    uuid: $uuid
    alterId: $alterId
    cipher: $securitys
EOF
    if [ ! -z "$udp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    udp: $udp
EOF
    fi
    if [ ! -z "$xudp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    xudp: $xudp
EOF
    fi
    if [ ! -z "$packet_encoding" ]; then
cat >> "$SERVER_FILE" <<-EOF
    packet-encoding: "$packet_encoding"
EOF
    fi
    if [ ! -z "$global_padding" ]; then
cat >> "$SERVER_FILE" <<-EOF
    global-padding: $global_padding
EOF
    fi
    if [ ! -z "$authenticated_length" ]; then
cat >> "$SERVER_FILE" <<-EOF
    authenticated-length: $authenticated_length
EOF
    fi
    if [ ! -z "$skip_cert_verify" ]; then
cat >> "$SERVER_FILE" <<-EOF
    skip-cert-verify: $skip_cert_verify
EOF
    fi
    if [ ! -z "$tls" ]; then
cat >> "$SERVER_FILE" <<-EOF
    tls: $tls
EOF
    fi
    if [ ! -z "$fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
    fingerprint: "$fingerprint"
EOF
    fi
    if [ ! -z "$client_fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
    client-fingerprint: "$client_fingerprint"
EOF
    fi
    if [ ! -z "$servername" ] && [ "$tls" = "true" ]; then
cat >> "$SERVER_FILE" <<-EOF
    servername: "$servername"
EOF
    fi
    if [ "$obfs_vmess" != "none" ]; then
cat >> "$SERVER_FILE" <<-EOF
    $obfs_vmess
EOF
        if [ "$obfs_vmess" = "network: ws" ]; then
            if [ ! -z "$path" ]; then
cat >> "$SERVER_FILE" <<-EOF
    $path
EOF
            fi
            if [ ! -z "$custom" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ws-headers:
      $custom
EOF
            fi
            if [ -n "$ws_opts_path" ] || [ -n "$ws_opts_headers" ] || [ -n "$max_early_data" ] || [ -n "$early_data_header_name" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ws-opts:
EOF
                if [ -n "$ws_opts_path" ]; then
cat >> "$SERVER_FILE" <<-EOF
      path: "$ws_opts_path"
EOF
                fi
                if [ -n "$ws_opts_headers" ]; then
cat >> "$SERVER_FILE" <<-EOF
      headers:
EOF
                    config_list_foreach "$section" "ws_opts_headers" set_ws_headers
                fi
                if [ -n "$max_early_data" ]; then
cat >> "$SERVER_FILE" <<-EOF
      max-early-data: $max_early_data
EOF
                fi
                if [ -n "$early_data_header_name" ]; then
cat >> "$SERVER_FILE" <<-EOF
      early-data-header-name: "$early_data_header_name"
EOF
                fi
            fi
        fi
        if [ "$obfs_vmess" = "network: http" ]; then
            if [ ! -z "$http_path" ]; then
cat >> "$SERVER_FILE" <<-EOF
    http-opts:
      method: "GET"
      path:
EOF
                config_list_foreach "$section" "http_path" set_http_path
            fi
            if [ "$keep_alive" = "true" ]; then
cat >> "$SERVER_FILE" <<-EOF
      headers:
        Connection:
          - keep-alive
EOF
            fi
        fi
        #h2
        if [ "$obfs_vmess" = "network: h2" ]; then
            if [ ! -z "$h2_host" ]; then
cat >> "$SERVER_FILE" <<-EOF
    h2-opts:
      host:
EOF
                config_list_foreach "$section" "h2_host" set_h2_host
            fi
            if [ ! -z "$h2_path" ]; then
cat >> "$SERVER_FILE" <<-EOF
      path: $h2_path
EOF
            fi
        fi
        if [ ! -z "$grpc_service_name" ] && [ "$obfs_vmess" = "network: grpc" ]; then
cat >> "$SERVER_FILE" <<-EOF
    grpc-opts:
      grpc-service-name: "$grpc_service_name"
EOF
        fi
    fi
fi

#hysteria2
if [ "$type" = "hysteria2" ]; then
   config_get "password" "$section" "password" ""
   config_get "hysteria_up" "$section" "hysteria_up" ""
   config_get "hysteria_down" "$section" "hysteria_down" ""
   config_get "hysteria_alpn" "$section" "hysteria_alpn" ""
   config_get "hysteria_obfs" "$section" "hysteria_obfs" ""
   config_get "hysteria_obfs_password" "$section" "hysteria_obfs_password" ""
   config_get "hysteria_ca" "$section" "hysteria_ca" ""
   config_get "hysteria_ca_str" "$section" "hysteria_ca_str" ""
   config_get "initial_stream_receive_window" "$section" "initial_stream_receive_window" ""
   config_get "max_stream_receive_window" "$section" "max_stream_receive_window" ""
   config_get "initial_connection_receive_window" "$section" "initial_connection_receive_window" ""
   config_get "max_connection_receive_window" "$section" "max_connection_receive_window" ""
   config_get "ports" "$section" "ports" ""
   config_get "hysteria2_protocol" "$section" "hysteria2_protocol" ""
   config_get "hop_interval" "$section" "hop_interval" ""

cat >> "$SERVER_FILE" <<-EOF
  - name: "$name"
    type: $type
    server: "$server"
    port: $port
    password: "$password"
EOF
    if [ -n "$hysteria_up" ]; then
cat >> "$SERVER_FILE" <<-EOF
    up: "$hysteria_up"
EOF
    fi
    if [ -n "$hysteria_down" ]; then
cat >> "$SERVER_FILE" <<-EOF
    down: "$hysteria_down"
EOF
    fi
    if [ -n "$skip_cert_verify" ]; then
cat >> "$SERVER_FILE" <<-EOF
    skip-cert-verify: $skip_cert_verify
EOF
    fi
    if [ -n "$sni" ]; then
cat >> "$SERVER_FILE" <<-EOF
    sni: "$sni"
EOF
    fi
    if [ -n "$hysteria_alpn" ]; then
        if [ -z "$(echo $hysteria_alpn |grep ' ')" ]; then
cat >> "$SERVER_FILE" <<-EOF
    alpn: 
      - "$hysteria_alpn"
EOF
        else
cat >> "$SERVER_FILE" <<-EOF
    alpn:
EOF
            config_list_foreach "$section" "hysteria_alpn" set_alpn
        fi
    fi
    if [ -n "$hysteria_obfs" ]; then
cat >> "$SERVER_FILE" <<-EOF
    obfs: "$hysteria_obfs"
EOF
    fi
    if [ -n "$hysteria_obfs_password" ]; then
cat >> "$SERVER_FILE" <<-EOF
    obfs-password: "$hysteria_obfs_password"
EOF
    fi
    if [ -n "$hysteria_ca" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ca: "$hysteria_ca"
EOF
    fi
    if [ -n "$hysteria_ca_str" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ca-str: "$hysteria_ca_str"
EOF
    fi
    if [ -n "$initial_stream_receive_window" ]; then
cat >> "$SERVER_FILE" <<-EOF
    initial-stream-receive-window: "$initial_stream_receive_window"
EOF
    fi
    if [ -n "$max_stream_receive_window" ]; then
cat >> "$SERVER_FILE" <<-EOF
    max-stream-receive-window: "$max_stream_receive_window"
EOF
    fi
    if [ -n "$initial_connection_receive_window" ]; then
cat >> "$SERVER_FILE" <<-EOF
    initial-connection-receive-window: "$initial_connection_receive_window"
EOF
    fi
    if [ -n "$max_connection_receive_window" ]; then
cat >> "$SERVER_FILE" <<-EOF
    max-connection-receive-window: "$max_connection_receive_window"
EOF
    fi
    if [ -n "$fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
    fingerprint: "$fingerprint"
EOF
    fi
    if [ -n "$ports" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ports: $ports
EOF
    fi
    if [ -n "$hysteria2_protocol" ]; then
cat >> "$SERVER_FILE" <<-EOF
    protocol: $hysteria2_protocol
EOF
    fi
    if [ -n "$hop_interval" ]; then
cat >> "$SERVER_FILE" <<-EOF
    hop-interval: $hop_interval
EOF
    fi
fi

#vless
if [ "$type" = "vless" ]; then
   config_get "uuid" "$section" "uuid" ""
   config_get "xudp" "$section" "xudp" ""
   config_get "packet_addr" "$section" "packet_addr" ""
   config_get "packet_encoding" "$section" "packet_encoding" ""
   config_get "servername" "$section" "servername" ""
   config_get "obfs_vless" "$section" "obfs_vless" ""
   config_get "ws_opts_path" "$section" "ws_opts_path" ""
   config_get "ws_opts_headers" "$section" "ws_opts_headers" ""
   config_get "grpc_service_name" "$section" "grpc_service_name" ""
   config_get "reality_public_key" "$section" "reality_public_key" ""
   config_get "reality_short_id" "$section" "reality_short_id" ""
   config_get "vless_flow" "$section" "vless_flow" ""
   config_get "xhttp_opts_path" "$section" "xhttp_opts_path" ""
   config_get "xhttp_opts_host" "$section" "xhttp_opts_host" ""
   config_get "vless_encryption" "$section" "vless_encryption" ""

   if [ "$obfs_vless" = "ws" ]; then
      obfs_vless="network: ws"
   fi
   if [ "$obfs_vless" = "grpc" ]; then
      obfs_vless="network: grpc"
   fi
   if [ "$obfs_vless" = "tcp" ]; then
      obfs_vless="network: tcp"
   fi
   if [ "$obfs_vless" = "xhttp" ]; then
      obfs_vless="network: xhttp"
   fi

cat >> "$SERVER_FILE" <<-EOF
  - name: "$name"
    type: $type
    server: "$server"
    port: $port
    uuid: $uuid
EOF
    if [ ! -z "$udp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    udp: $udp
EOF
    fi
    if [ ! -z "$xudp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    xudp: $xudp
EOF
    fi
    if [ ! -z "$packet_addr" ]; then
cat >> "$SERVER_FILE" <<-EOF
    packet-addr: $packet_addr
EOF
    fi
    if [ ! -z "$packet_encoding" ]; then
cat >> "$SERVER_FILE" <<-EOF
    packet-encoding: "$packet_encoding"
EOF
    fi
    if [ ! -z "$skip_cert_verify" ]; then
cat >> "$SERVER_FILE" <<-EOF
    skip-cert-verify: $skip_cert_verify
EOF
    fi
    if [ ! -z "$tls" ]; then
cat >> "$SERVER_FILE" <<-EOF
    tls: $tls
EOF
    fi
    if [ ! -z "$fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
    fingerprint: "$fingerprint"
EOF
    fi
    if [ ! -z "$client_fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
    client-fingerprint: "$client_fingerprint"
EOF
    fi
    if [ ! -z "$servername" ]; then
cat >> "$SERVER_FILE" <<-EOF
    servername: "$servername"
EOF
    fi
    if [ -n "$obfs_vless" ]; then
cat >> "$SERVER_FILE" <<-EOF
    $obfs_vless
EOF
        if [ "$obfs_vless" = "network: ws" ]; then
            if [ -n "$ws_opts_path" ] || [ -n "$ws_opts_headers" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ws-opts:
EOF
                if [ -n "$ws_opts_path" ]; then
cat >> "$SERVER_FILE" <<-EOF
      path: "$ws_opts_path"
EOF
                fi
                if [ -n "$ws_opts_headers" ]; then
cat >> "$SERVER_FILE" <<-EOF
      headers:
EOF
                  config_list_foreach "$section" "ws_opts_headers" set_ws_headers
                fi
            fi
        fi
        if [ ! -z "$grpc_service_name" ] && [ "$obfs_vless" = "network: grpc" ]; then
cat >> "$SERVER_FILE" <<-EOF
    grpc-opts:
      grpc-service-name: "$grpc_service_name"
EOF
            if [ -n "$reality_public_key" ] || [ -n "$reality_short_id" ]; then
cat >> "$SERVER_FILE" <<-EOF
    reality-opts:
EOF
            fi
            if [ -n "$reality_public_key" ]; then
cat >> "$SERVER_FILE" <<-EOF
      public-key: "$reality_public_key"
EOF
            fi
            if [ -n "$reality_short_id" ]; then
cat >> "$SERVER_FILE" <<-EOF
      short-id: "$reality_short_id"
EOF
            fi
        fi
        if [ "$obfs_vless" = "network: tcp" ]; then
            if [ ! -z "$vless_flow" ]; then
cat >> "$SERVER_FILE" <<-EOF
    flow: "$vless_flow"
EOF
            fi
            if [ -n "$vless_encryption" ]; then
cat >> "$SERVER_FILE" <<-EOF
      encryption: "$vless_encryption"
EOF
            fi
            if [ -n "$reality_public_key" ] || [ -n "$reality_short_id" ]; then
cat >> "$SERVER_FILE" <<-EOF
    reality-opts:
EOF
            fi
            if [ -n "$reality_public_key" ]; then
cat >> "$SERVER_FILE" <<-EOF
      public-key: "$reality_public_key"
EOF
            fi
            if [ -n "$reality_short_id" ]; then
cat >> "$SERVER_FILE" <<-EOF
      short-id: "$reality_short_id"
EOF
            fi
        fi
        if [ "$obfs_vless" = "network: xhttp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    xhttp-opts:
EOF
            if [ -n "$xhttp_opts_path" ]; then
cat >> "$SERVER_FILE" <<-EOF
      path: "$xhttp_opts_path"
EOF
            fi
            if [ -n "$xhttp_opts_host" ]; then
cat >> "$SERVER_FILE" <<-EOF
      host: "$xhttp_opts_host"
EOF
            fi
        fi
    fi
fi

#trojan
if [ "$type" = "trojan" ]; then
   config_get "grpc_service_name" "$section" "grpc_service_name" ""
   config_get "obfs_trojan" "$section" "obfs_trojan" ""
   config_get "trojan_ws_path" "$section" "trojan_ws_path" ""
   config_get "trojan_ws_headers" "$section" "trojan_ws_headers" ""

cat >> "$SERVER_FILE" <<-EOF
  - name: "$name"
    type: $type
    server: "$server"
    port: $port
    password: "$password"
EOF
    if [ ! -z "$udp" ]; then
cat >> "$SERVER_FILE" <<-EOF
    udp: $udp
EOF
    fi
    if [ ! -z "$sni" ]; then
cat >> "$SERVER_FILE" <<-EOF
    sni: "$sni"
EOF
    fi
    if [ ! -z "$alpn" ]; then
cat >> "$SERVER_FILE" <<-EOF
    alpn:
EOF
        config_list_foreach "$section" "alpn" set_alpn
    fi
    if [ ! -z "$skip_cert_verify" ]; then
cat >> "$SERVER_FILE" <<-EOF
    skip-cert-verify: $skip_cert_verify
EOF
    fi
    if [ ! -z "$fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
  fingerprint: "$fingerprint"
EOF
    fi
    if [ ! -z "$client_fingerprint" ]; then
cat >> "$SERVER_FILE" <<-EOF
  client-fingerprint: "$client_fingerprint"
EOF
    fi
    if [ ! -z "$grpc_service_name" ]; then
cat >> "$SERVER_FILE" <<-EOF
    network: grpc
    grpc-opts:
      grpc-service-name: "$grpc_service_name"
EOF
    fi
    if [ "$obfs_trojan" = "ws" ]; then
        if [ -n "$trojan_ws_path" ] || [ -n "$trojan_ws_headers" ]; then
cat >> "$SERVER_FILE" <<-EOF
    network: ws
    ws-opts:
EOF
        fi
        if [ -n "$trojan_ws_path" ]; then
cat >> "$SERVER_FILE" <<-EOF
      path: "$trojan_ws_path"
EOF
        fi
        if [ -n "$trojan_ws_headers" ]; then
cat >> "$SERVER_FILE" <<-EOF
      headers:
EOF
         config_list_foreach "$section" "trojan_ws_headers" set_ws_headers
        fi
    fi
fi

#ip_version
if [ ! -z "$ip_version" ]; then
cat >> "$SERVER_FILE" <<-EOF
    ip-version: "$ip_version"
EOF
fi

#TFO
if [ ! -z "$tfo" ]; then
cat >> "$SERVER_FILE" <<-EOF
    tfo: $tfo
EOF
fi

#Multiplex
if [ ! -z "$multiplex" ]; then
cat >> "$SERVER_FILE" <<-EOF
    smux:
      enabled: $multiplex
EOF
    if [ -n "$multiplex_protocol" ]; then
cat >> "$SERVER_FILE" <<-EOF
      protocol: $multiplex_protocol
EOF
    fi
    if [ -n "$multiplex_max_connections" ]; then
cat >> "$SERVER_FILE" <<-EOF
      max-connections: $multiplex_max_connections
EOF
    fi
    if [ -n "$multiplex_min_streams" ]; then
cat >> "$SERVER_FILE" <<-EOF
      min-streams: $multiplex_min_streams
EOF
    fi
    if [ -n "$multiplex_max_streams" ]; then
cat >> "$SERVER_FILE" <<-EOF
      max-streams: $multiplex_max_streams
EOF
    fi
    if [ -n "$multiplex_padding" ]; then
cat >> "$SERVER_FILE" <<-EOF
      padding: $multiplex_padding
EOF
    fi
    if [ -n "$multiplex_statistic" ]; then
cat >> "$SERVER_FILE" <<-EOF
      statistic: $multiplex_statistic
EOF
    fi
    if [ -n "$multiplex_only_tcp" ]; then
cat >> "$SERVER_FILE" <<-EOF
      only-tcp: $multiplex_only_tcp
EOF
    fi
fi

#interface-name
if [ -n "$interface_name" ]; then
cat >> "$SERVER_FILE" <<-EOF
    interface-name: "$interface_name"
EOF
fi

#routing_mark
if [ -n "$routing_mark" ]; then
cat >> "$SERVER_FILE" <<-EOF
    routing-mark: "$routing_mark"
EOF
fi

#other_parameters
if [ -n "$other_parameters" ]; then
    echo -e "$other_parameters" >> "$SERVER_FILE"
fi

#dialer_proxy
if [ -n "$dialer_proxy" ]; then
cat >> "$SERVER_FILE" <<-EOF
    dialer-proxy: "$dialer_proxy"
EOF
fi
}

yml_servers_name_get()
{
	 local section="$1"
   local name
   config_get "name" "$section" "name" ""
   [ ! -z "$name" ] && {
      echo "$name" >>"$servers_name"
   }
}

yml_proxy_provider_name_get()
{
	 local section="$1"
   local name
   config_get "name" "$section" "name" ""
   [ ! -z "$name" ] && {
      echo "$name" >>"$proxy_provider_name"
   }
}

# Create config file
config_load "clashnivo"
config_foreach yml_servers_name_get "servers"
config_foreach yml_proxy_provider_name_get "proxy-provider"

#proxy-provider
LOG_OUT "Start Writing[$CONFIG_NAME]Proxy-providers Setting..."
echo "proxy-providers:" >$PROXY_PROVIDER_FILE
rm -rf /tmp/Proxy_Provider
config_foreach yml_proxy_provider_set "proxy-provider"
sed -i "s/^ \{0,\}/      - /" /tmp/Proxy_Provider 2>/dev/null # add list prefix
if [ "$(grep "-" /tmp/Proxy_Provider 2>/dev/null |wc -l)" -eq 0 ]; then
   rm -rf $PROXY_PROVIDER_FILE
   rm -rf /tmp/Proxy_Provider
fi
rm -rf $proxy_provider_name

#proxy
LOG_OUT "Start Writing[$CONFIG_NAME]Proxies Setting..."
echo "proxies:" >$SERVER_FILE
config_foreach yml_servers_set "servers"
egrep '^ {0,}-' $SERVER_FILE |grep name: |awk -F 'name: ' '{print $2}' |sed 's/,.*//' 2>/dev/null >/tmp/Proxy_Server 2>&1
if [ -s "/tmp/Proxy_Server" ]; then
   sed -i "s/^ \{0,\}/      - /" /tmp/Proxy_Server 2>/dev/null # add list prefix
else
   rm -rf $SERVER_FILE
   rm -rf /tmp/Proxy_Server
fi
rm -rf $servers_name


LOG_OUT "Proxies, Proxy-providers, Groups Edited Successful, Updating Config File[$CONFIG_NAME]..."
config_hash=$(ruby -ryaml -rYAML -I "/usr/share/clashnivo" -E UTF-8 -e "Value = YAML.load_file('$CONFIG_FILE'); puts Value" 2>/dev/null)
if [ "$config_hash" != "false" ] && [ -n "$config_hash" ]; then
    ruby_cover "$CONFIG_FILE" "['proxies']" "$SERVER_FILE" "proxies"
    ruby_cover "$CONFIG_FILE" "['proxy-providers']" "$PROXY_PROVIDER_FILE" "proxy-providers"
    ruby_cover "$CONFIG_FILE" "['proxy-groups']" "/tmp/yaml_groups.yaml" "proxy-groups"
else
    cat "$SERVER_FILE" "$PROXY_PROVIDER_FILE" "/tmp/yaml_groups.yaml" > "$CONFIG_FILE" 2>/dev/null
fi

rm -rf $SERVER_FILE 2>/dev/null
rm -rf $PROXY_PROVIDER_FILE 2>/dev/null
rm -rf /tmp/yaml_groups.yaml 2>/dev/null
rm -rf /tmp/Proxy_Server 2>/dev/null
rm -rf /tmp/Proxy_Provider 2>/dev/null

LOG_OUT "Config File[$CONFIG_NAME]Write Successful!"
SLOG_CLEAN
del_lock