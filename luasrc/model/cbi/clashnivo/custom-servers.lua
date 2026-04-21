--[[
Custom proxy server list (section type `servers`, per uci-schema.md §3).

Tabular add/edit/remove of manually-defined proxies. These are injected into
every applicable config at Stage 3 by yml_proxys_set.sh.

Scope cuts vs OpenClash:
  - Only the five v1 protocols (ss, vmess, vless, trojan, hysteria2). SSR,
    snell, tuic, wireguard, mieru, anytls, socks5, http, ssh, etc. are all
    dropped (see schema cut list).
  - No proxy-provider section — that's DEFERRED post-v1.
  - No "Read Config" bulk import from YAML (OpenClash's yml_groups_get.sh
    path). URL import (ss:// / vmess:// / vless:// / trojan:// / hysteria2://)
    is supported via the import widget below the table.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"

local m, s, o

m = Map("clashnivo", translate("Custom Servers"),
	translate("Manually-defined proxy nodes. Added on top of every subscription config at assembly time."))
m.pageaction = false

s = m:section(TypedSection, "servers", translate("Server List"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = DISP.build_url("admin/services/clashnivo/custom-servers-edit/%s")

function s.create(...)
	local sid = TypedSection.create(...)
	if sid then
		HTTP.redirect(s.extedit % sid)
		return
	end
end

o = s:option(Flag, "enabled", translate("Enabled"))
o.rmempty = false
o.default = "1"
o.cfgvalue = function(...) return Flag.cfgvalue(...) or "1" end

o = s:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return v and v:upper() or "?"
end

o = s:option(DummyValue, "name", translate("Name"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or translate("(unnamed)")
end

o = s:option(DummyValue, "server", translate("Server"))
o = s:option(DummyValue, "port", translate("Port"))

o = s:option(DummyValue, "config", translate("Applies To"))
function o.cfgvalue(self, section)
	local v = self.map:get(section, "config")
	if type(v) == "table" then v = table.concat(v, ", ") end
	if not v or v == "" then return "all" end
	return v
end

-- URL import widget below the table.
m:append(Template("clashnivo/server_url_import"))
m:append(Template("clashnivo/toolbar_show"))

return m
