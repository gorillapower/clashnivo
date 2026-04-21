--[[
Settings CBI — tabbed editor for the clashnivo.config singleton.

Epic 1 populates three tabs (op_mode, ports, dns) with the minimum fields
Epic 1 requires. Six additional tabs are declared as empty shells so Epic 5
can add options without restructuring the page or shifting the URL fragment
anchors. Field-level additions in those tabs are out of Epic 1 scope.

Field inventory is authoritative in docs/architecture/uci-schema.md §1.1–§1.4;
keep the ordering and defaults aligned with that document.
]]--

local fs = require "luci.clashnivo"

local m = Map("clashnivo", translate("Settings"))
m.pageaction = false
m.description = translate("Global settings for Clash Nivo. Ports and DNS redirect mode default values allow side-by-side coexistence with other Clash/Mihomo installs.")

local s = m:section(NamedSection, "config", "clashnivo")
s.anonymous = true
s.addremove = false

-- Epic 1 live tabs
s:tab("op_mode", translate("Operation Mode"))
s:tab("ports",   translate("Ports"))
s:tab("dns",     translate("DNS"))

-- Epic 5 stub tabs — declared now to freeze URL anchors. Each carries one
-- DummyValue "stub" row so LuCI renders the tab instead of hiding it for
-- having zero visible options.
s:tab("traffic_control", translate("Traffic Control"))
s:tab("lan_ac",          translate("LAN Access Control"))
s:tab("dashboard",       translate("Dashboard"))
s:tab("rules_update",    translate("Rules Update"))
s:tab("geo_update",      translate("GEO Data"))
s:tab("auto_restart",    translate("Auto Restart"))

------------------------------------------------------------------------------
-- Tab: Operation Mode
------------------------------------------------------------------------------
local o

o = s:taboption("op_mode", ListValue, "operation_mode", translate("Transparent Proxy Mode"))
o.description = translate("fake-ip: faster, handles domain-based rules natively. redir-host: routes DNS through core; more accurate but slower.")
o:value("fake-ip",   translate("Fake-IP"))
o:value("redir-host", translate("Redir-Host"))
o.default = "fake-ip"

o = s:taboption("op_mode", ListValue, "proxy_mode", translate("Proxy Mode"))
o.description = translate("Rule: apply the subscription's rules. Global: send all traffic to the selected proxy. Direct: bypass proxy entirely.")
o:value("rule",   translate("Rule"))
o:value("global", translate("Global"))
o:value("direct", translate("Direct"))
o.default = "rule"

o = s:taboption("op_mode", ListValue, "log_level", translate("Log Level"))
o:value("silent",  translate("Silent"))
o:value("error",   translate("Error"))
o:value("warning", translate("Warning"))
o:value("info",    translate("Info"))
o:value("debug",   translate("Debug"))
o.default = "info"

o = s:taboption("op_mode", Flag, "enable_udp_proxy", translate("Proxy UDP Traffic"))
o.description = translate("Forward UDP through the core. Servers must support UDP relay.")
o.default = "1"

o = s:taboption("op_mode", Flag, "enable", translate("Service Enabled"))
o.description = translate("Master switch. When off, init.d will not start the core at boot.")
o.default = "0"

------------------------------------------------------------------------------
-- Tab: Ports
------------------------------------------------------------------------------
local function port_option(key, label, default, desc)
	local opt = s:taboption("ports", Value, key, label)
	opt.datatype = "port"
	opt.default = default
	if desc then opt.description = desc end
	return opt
end

port_option("mixed_port",  translate("Mixed Port"),       "7993", translate("HTTP + SOCKS5 combined port"))
port_option("http_port",   translate("HTTP Port"),        "7990")
port_option("socks_port",  translate("SOCKS5 Port"),      "7991")
port_option("proxy_port",  translate("Redir Port"),       "7992", translate("Transparent TCP redirect (redir-host mode)"))
port_option("tproxy_port", translate("TProxy Port"),      "7995", translate("Transparent TPROXY (UDP)"))
port_option("dns_port",    translate("DNS Port"),         "7974", translate("Core-internal DNS listener"))
port_option("cn_port",     translate("REST API Port"),    "9190", translate("External controller / dashboard port"))

o = s:taboption("ports", Value, "common_ports", translate("Forwarded TCP Ports"))
o.default = "0"
o.description = translate("Ports to forward through the core. Set to 0 for all ports.")

------------------------------------------------------------------------------
-- Tab: DNS
------------------------------------------------------------------------------
o = s:taboption("dns", ListValue, "enable_redirect_dns", translate("DNS Redirect Mode"))
o.description = translate("How to route local DNS queries through the core.")
o:value("0", translate("Off — do not redirect"))
o:value("1", translate("Dnsmasq redirect (recommended)"))
o:value("2", translate("Firewall redirect"))
o.default = "1"

o = s:taboption("dns", Value, "fakeip_range", translate("Fake-IP Range"))
o.datatype = "ip4addr"
o.default = "198.18.0.0/15"
o.description = translate("CIDR range for synthesised fake IPs. Only applies in fake-ip mode.")

o = s:taboption("dns", Flag, "store_fakeip", translate("Persist Fake-IP Mappings"))
o.description = translate("Keep fake-ip assignments across core restarts.")
o.default = "0"

o = s:taboption("dns", Flag, "disable_masq_cache", translate("Disable Dnsmasq Cache While Running"))
o.description = translate("Prevents stale DNS answers from dnsmasq short-circuiting the core's resolver.")
o.default = "1"

------------------------------------------------------------------------------
-- Epic 5 stub tabs — each declares one DummyValue so the tab renders as
-- "empty / coming soon" instead of being hidden by LuCI for having no
-- options. Replace these with real options in Epic 5.
------------------------------------------------------------------------------
local function stub_tab(tab)
	local d = s:taboption(tab, DummyValue, "_stub_" .. tab, "")
	d.rawhtml = true
	d.value = "<em>" .. translate("Coming in a later release.") .. "</em>"
end

stub_tab("traffic_control")
stub_tab("lan_ac")
stub_tab("dashboard")
stub_tab("rules_update")
stub_tab("geo_update")
stub_tab("auto_restart")

return m
