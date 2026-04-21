#!/bin/sh
. /usr/share/clashnivo/log.sh
. /usr/share/clashnivo/uci.sh

set_lock() {
   exec 883>"/tmp/lock/clashnivo_cus_domian.lock" 2>/dev/null
   flock -x 883 2>/dev/null
}

del_lock() {
   flock -u 883 2>/dev/null
   rm -rf "/tmp/lock/clashnivo_cus_domian.lock"
}

set_lock

# Get the default DNSMASQ config ID
DEFAULT_DNSMASQ_CFGID="$(uci -q show "dhcp.@dnsmasq[0]" | awk 'NR==1 {split($0, conf, /[.=]/); print conf[2]}')"
# Extract conf-dir path from the dnsmasq runtime conf file
if [ -f "/tmp/etc/dnsmasq.conf.$DEFAULT_DNSMASQ_CFGID" ]; then
   DNSMASQ_CONF_DIR="$(awk -F '=' '/^conf-dir=/ {print $2}' "/tmp/etc/dnsmasq.conf.$DEFAULT_DNSMASQ_CFGID")"
else
   DNSMASQ_CONF_DIR="/tmp/dnsmasq.d"
fi
# Normalise DNSMASQ_CONF_DIR by stripping any trailing slash
DNSMASQ_CONF_DIR=${DNSMASQ_CONF_DIR%*/}
rm -rf ${DNSMASQ_CONF_DIR}/dnsmasq_clashnivo_custom_domain.conf >/dev/null 2>&1
if [ "$(uci_get_config "enable_custom_domain_dns_server")" = "1" ] && [ "$(uci_get_config "enable_redirect_dns")" = "1" ]; then
   LOG_OUT "Setting Secondary DNS Server List..."

   custom_domain_dns_server=$(uci_get_config "custom_domain_dns_server")
   [ -z "$custom_domain_dns_server" ] && {
	   custom_domain_dns_server="114.114.114.114"
	}

   if [ -s "/etc/clashnivo/custom/clashnivo_custom_domain_dns.list" ]; then
      mkdir -p ${DNSMASQ_CONF_DIR}
      awk -v tag="$custom_domain_dns_server" '!/^$/&&!/^#/{printf("server=/%s/"'tag'"\n",$0)}' /etc/clashnivo/custom/clashnivo_custom_domain_dns.list >>${DNSMASQ_CONF_DIR}/dnsmasq_clashnivo_custom_domain.conf 2>/dev/null
   fi
fi

del_lock
