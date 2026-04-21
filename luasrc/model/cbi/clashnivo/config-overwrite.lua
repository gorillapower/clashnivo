--[[
Config overwrite list (Epic 3d).

One page with a single TypedSection table for `config_overwrite` (uci-schema
§6). Each row is either an inline YAML overlay authored in this UI or a remote
URL that the init.d cron (add_overwrite_cron) periodically pulls. Sections are
applied in `order` at Stage 6 by init.d's overwrite_file() — lower order runs
first, later sources win key-for-key.

Scope cuts vs OpenClash:
  - No separate overwrite-body file manager UI. Inline bodies are edited in
    the per-section edit page; remote URLs are fetched by cron into the same
    on-disk path.
  - No CodeMirror editor yet — luci-static assets aren't vendored. The edit
    page falls back to a plain textarea. Follow-up: drop CodeMirror + YAML
    mode under root/www/luci-static/resources/clashnivo/.
  - Editing `[General]` / `[Overwrite]` ruby-script blocks is not exposed.
    Inline bodies are pure YAML; the CBI wraps them as `[YAML]` for init.d.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"

local m, s, o

m = Map("clashnivo", translate("Config Overwrite"),
	translate("Apply YAML overlays on top of the subscription config before Mihomo starts. Sources run in ascending `order`; later sources override earlier ones. Use an inline body for one-off tweaks, or point at a remote URL for community-maintained overlays."))
m.pageaction = false

s = m:section(TypedSection, "config_overwrite", translate("Overwrite Sources"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = DISP.build_url("admin/services/clashnivo/config-overwrite-edit/%s")

function s.create(...)
	local sid = TypedSection.create(...)
	if sid then
		HTTP.redirect(s.extedit % sid)
		return
	end
end

o = s:option(Flag, "enabled", translate("Enabled"))
o.rmempty = false
o.default = "0"
o.cfgvalue = function(...) return Flag.cfgvalue(...) or "0" end

o = s:option(DummyValue, "name", translate("Name"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or translate("(unnamed)")
end

o = s:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(self, section)
	local t = Value.cfgvalue(self, section) or "inline"
	if t == "http"   then return translate("Remote URL") end
	if t == "inline" then return translate("Inline YAML") end
	return t
end

o = s:option(DummyValue, "order", translate("Order"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or "1"
end

o = s:option(DummyValue, "url", translate("Source"))
function o.cfgvalue(self, section)
	local t = self.map:get(section, "type") or "inline"
	if t == "inline" then return translate("(inline)") end
	local u = self.map:get(section, "url") or "—"
	if #u > 48 then u = string.sub(u, 1, 45) .. "…" end
	return u
end

o = s:option(DummyValue, "schedule", translate("Auto-Update"))
function o.cfgvalue(self, section)
	local t = self.map:get(section, "type") or "inline"
	if t ~= "http" then return "—" end
	local day  = self.map:get(section, "update_days") or "off"
	local hour = self.map:get(section, "update_hour") or "off"
	if day == "off" or hour == "off" then return translate("off") end
	return string.format("%sh day %s", hour, day)
end

o = s:option(DummyValue, "config", translate("Applies To"))
function o.cfgvalue(self, section)
	local v = self.map:get(section, "config")
	if type(v) == "table" then v = table.concat(v, ", ") end
	if not v or v == "" then return "all" end
	return v
end

m:append(Template("clashnivo/toolbar_show"))

return m
