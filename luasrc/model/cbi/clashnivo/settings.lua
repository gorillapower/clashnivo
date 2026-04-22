--[[
Settings CBI — two-tab editor for the clashnivo.config singleton.

Per docs/architecture/ui-nav.md §Settings the page is tabbed by responsibility:

  Clash  — settings that configure the Mihomo binary or its generated
           config.yaml (operation mode, proxy mode, UDP toggle, listener
           ports, fake-IP range, API controller port).
  Router — settings that configure OpenWrt firewall/dnsmasq (DNS redirect
           method, common-ports allowlist, dnsmasq cache disable).

Field inventory is authoritative in docs/architecture/uci-schema.md §1.1–§1.4;
keep the ordering and defaults aligned with that document.

Placement notes:
  - `log_level` lives on the Log page (live-switched via switch_log endpoint).
  - `enable` (service master switch) lives on the Overview page (start/stop
    buttons). Not duplicated here.
  - Epic 5 fields (TUN stack, TProxy/DNS customisation, dashboard install,
    device access, WAN bypass, custom firewall, etc.) will slot into Clash or
    Router per the same responsibility principle when they land — see the doc.
]]--

local m = Map("clashnivo", translate("Settings"))
m.description = translate("Global settings for Clash Nivo. Port defaults diverge from OpenClash to allow side-by-side coexistence.")

local s = m:section(NamedSection, "config", "clashnivo")
s.anonymous = true
s.addremove = false

s:tab("clash",  translate("Clash"),
	translate("Settings that configure the Mihomo binary or its generated config.yaml."))
s:tab("router", translate("Router"),
	translate("Settings that configure the OpenWrt firewall (iptables/nftables) and dnsmasq."))

------------------------------------------------------------------------------
-- Tab: Clash — Mihomo binary / config.yaml concerns
------------------------------------------------------------------------------
local o

o = s:taboption("clash", ListValue, "operation_mode", translate("Transparent Proxy Mode"))
o.description = translate("fake-ip: faster, handles domain-based rules natively. redir-host: routes DNS through core; more accurate but slower.")
o:value("fake-ip",    translate("Fake-IP"))
o:value("redir-host", translate("Redir-Host"))
o.default = "fake-ip"

o = s:taboption("clash", ListValue, "proxy_mode", translate("Proxy Mode"))
o.description = translate("Rule: apply the subscription's rules. Global: send all traffic to the selected proxy. Direct: bypass proxy entirely.")
o:value("rule",   translate("Rule"))
o:value("global", translate("Global"))
o:value("direct", translate("Direct"))
o.default = "rule"

o = s:taboption("clash", Flag, "enable_udp_proxy", translate("Proxy UDP Traffic"))
o.description = translate("Forward UDP through the core. Servers must support UDP relay.")
o.default = "1"

local function port_option(key, label, default, desc)
	local opt = s:taboption("clash", Value, key, label)
	opt.datatype = "port"
	opt.default = default
	if desc then opt.description = desc end
	return opt
end

port_option("mixed_port",  translate("Mixed Port"),    "7993", translate("HTTP + SOCKS5 combined port"))
port_option("http_port",   translate("HTTP Port"),     "7990")
port_option("socks_port",  translate("SOCKS5 Port"),   "7991")
port_option("proxy_port",  translate("Redir Port"),    "7992", translate("Transparent TCP redirect (redir-host mode)"))
port_option("tproxy_port", translate("TProxy Port"),   "7995", translate("Transparent TPROXY (UDP)"))
port_option("dns_port",    translate("DNS Port"),      "7974", translate("Core-internal DNS listener"))
port_option("cn_port",     translate("REST API Port"), "9190", translate("External controller / dashboard port"))

o = s:taboption("clash", Value, "fakeip_range", translate("Fake-IP Range"))
o.datatype = "ip4addr"
o.default = "198.18.0.0/15"
o.description = translate("CIDR range for synthesised fake IPs. Only applies in fake-ip mode.")

o = s:taboption("clash", Flag, "store_fakeip", translate("Persist Fake-IP Mappings"))
o.description = translate("Keep fake-ip assignments across core restarts.")
o.default = "0"

------------------------------------------------------------------------------
-- Tab: Router — OpenWrt firewall / dnsmasq concerns
------------------------------------------------------------------------------
o = s:taboption("router", ListValue, "enable_redirect_dns", translate("DNS Redirect Mode"))
o.description = translate("How local DNS queries are routed through the core.")
o:value("0", translate("Off — do not redirect"))
o:value("1", translate("Dnsmasq redirect (recommended)"))
o:value("2", translate("Firewall redirect"))
o.default = "1"

o = s:taboption("router", Value, "common_ports", translate("Forwarded TCP Ports"))
o.default = "0"
o.description = translate("Which TCP ports are forwarded through the core. Set to 0 for all ports.")

o = s:taboption("router", Flag, "disable_masq_cache", translate("Disable Dnsmasq Cache While Running"))
o.description = translate("Prevents stale DNS answers from dnsmasq short-circuiting the core's resolver.")
o.default = "1"

return m
