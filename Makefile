include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-clashnivo
PKG_VERSION:=0.1.0
PKG_MAINTAINER:=gorillapower <https://github.com/gorillapower/clashnivo>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
	config PACKAGE_kmod-inet-diag
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_luci-compat
	default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_kmod-nft-tproxy
	default y if PACKAGE_firewall4

	config PACKAGE_kmod-ipt-nat
	default y if ! PACKAGE_firewall4

	config PACKAGE_iptables-mod-tproxy
	default y if ! PACKAGE_firewall4

	config PACKAGE_iptables-mod-extra
	default y if ! PACKAGE_firewall4

	config PACKAGE_dnsmasq_full_ipset
	default y if ! PACKAGE_firewall4

	config PACKAGE_dnsmasq_full_nftset
	default y if PACKAGE_firewall4

	config PACKAGE_ipset
	default y if ! PACKAGE_firewall4
endef

define Package/$(PKG_NAME)
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=Clash Nivo — Mihomo proxy manager for OpenWrt
	PKGARCH:=all
	DEPENDS:=+dnsmasq-full +bash +curl +ca-bundle +ip-full \
	+ruby +ruby-yaml +kmod-tun +unzip
	MAINTAINER:=gorillapower
endef

define Package/$(PKG_NAME)/description
    LuCI interface for managing the Mihomo (Clash Meta) transparent proxy
    on OpenWrt routers. Fork of OpenClash, English-first, simplified UX.
endef

define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)
	$(foreach po,$(wildcard ${CURDIR}/po/en/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/clashnivo
	chmod -R 0755 $(PKG_BUILD_DIR)/root/usr/share/clashnivo/
	mkdir -p $(PKG_BUILD_DIR)/root/etc/clashnivo/config
	mkdir -p $(PKG_BUILD_DIR)/root/etc/clashnivo/custom
	mkdir -p $(PKG_BUILD_DIR)/root/etc/clashnivo/core
	mkdir -p $(PKG_BUILD_DIR)/root/etc/clashnivo/history
	mkdir -p $(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/overwrite
	cp -f "$(PKG_BUILD_DIR)/root/etc/config/clashnivo" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_rules.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_rules.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_rules_2.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_rules_2.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_hosts.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_hosts.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_fake_filter.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_fake_filter.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_domain_dns.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_domain_dns.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_domain_dns_policy.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_domain_dns_policy.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_proxy_server_dns_policy.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_proxy_server_dns_policy.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_fallback_filter.yaml" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_fallback_filter.yaml" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_sniffer.yaml" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_sniffer.yaml" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_localnetwork_ipv4.list" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_localnetwork_ipv4.list" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_firewall_rules.sh" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_firewall_rules.sh" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/custom/clashnivo_custom_overwrite.sh" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/clashnivo_custom_overwrite.sh" >/dev/null 2>&1
	cp -f "$(PKG_BUILD_DIR)/root/etc/clashnivo/overwrite/default" "$(PKG_BUILD_DIR)/root/usr/share/clashnivo/backup/overwrite/default" >/dev/null 2>&1
	exit 0
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
	if [ -f "/etc/config/clashnivo" ] && [ ! -f "/tmp/clashnivo.bak" ]; then
		cp -f "/etc/config/clashnivo" "/tmp/clashnivo.bak" >/dev/null 2>&1
		cp -rf "/etc/clashnivo" "/tmp/clashnivo" >/dev/null 2>&1
		cp -rf "/usr/share/clashnivo/ui" "/tmp/clashnivo_ui" >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
	exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
	[ -n "$(pidof mihomo)" ] && /etc/init.d/clashnivo stop 2>/dev/null
	if [ -f "/etc/config/clashnivo" ] && [ ! -f "/tmp/clashnivo.bak" ]; then
		cp -f "/etc/config/clashnivo" "/tmp/clashnivo.bak" >/dev/null 2>&1
		cp -rf "/etc/clashnivo" "/tmp/clashnivo" >/dev/null 2>&1
		cp -rf "/usr/share/clashnivo/ui" "/tmp/clashnivo_ui" >/dev/null 2>&1
	fi
	exit 0
endef

define Package/$(PKG_NAME)/postrm
#!/bin/sh
	DEFAULT_DNSMASQ_CFGID="$$(uci -q show "dhcp.@dnsmasq[0]" | awk 'NR==1 {split($0, conf, /[.=]/); print conf[2]}' 2>/dev/null)"
	if [ -f "/tmp/etc/dnsmasq.conf.$DEFAULT_DNSMASQ_CFGID" ]; then
	   DNSMASQ_CONF_DIR="$$(awk -F '=' '/^conf-dir=/ {print $2}' "/tmp/etc/dnsmasq.conf.$DEFAULT_DNSMASQ_CFGID" 2>/dev/null)"
	else
	   DNSMASQ_CONF_DIR="/tmp/dnsmasq.d"
	fi
	DNSMASQ_CONF_DIR=$${DNSMASQ_CONF_DIR%*/}
	rm -rf /etc/clashnivo >/dev/null 2>&1
	rm -rf /etc/config/clashnivo >/dev/null 2>&1
	rm -rf /tmp/clashnivo.log >/dev/null 2>&1
	rm -rf /tmp/clashnivo_start.log >/dev/null 2>&1
	rm -rf /tmp/clashnivo_last_version >/dev/null 2>&1
	rm -rf /tmp/clashnivo.change >/dev/null 2>&1
	rm -rf /usr/share/clashnivo >/dev/null 2>&1
	rm -rf $${DNSMASQ_CONF_DIR}/dnsmasq_clashnivo_custom_domain.conf >/dev/null 2>&1
	rm -rf /tmp/etc/clashnivo >/dev/null 2>&1
	rm -rf /www/luci-static/resources/clashnivo >/dev/null 2>&1
	uci -q delete firewall.clashnivo
	uci -q commit firewall
	[ -f "/etc/config/ucitrack" ] && {
	uci -q delete ucitrack.@clashnivo[-1]
	uci -q commit ucitrack
	}
	rm -rf /tmp/luci-*
	exit 0
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
