--[[
Custom proxy group list (section type `groups`, per uci-schema.md §4).

Tabular add/edit/remove of manually-defined proxy groups. These are injected
into every applicable config at Stage 4 by yml_groups_set.sh.

Scope cuts vs OpenClash:
  - Four group types only (select, url-test, fallback, load-balance). The
    `smart` / LightGBM group type and all associated LightGBM plumbing are
    dropped (see schema cut list).
  - Every group emits `include-all-proxies: true`. There is no manual
    proxy-assignment UI — membership is controlled via `filter` /
    `exclude_filter` regex, plus optional `other_group` references.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"

local m, s, o

m = Map("clashnivo", translate("Custom Groups"),
	translate("Manually-defined proxy groups. Each group includes every proxy in the active config, narrowed by the filter/exclude regex."))
m.pageaction = false

s = m:section(TypedSection, "groups", translate("Group List"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = DISP.build_url("admin/services/clashnivo/custom-groups-edit/%s")

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

o = s:option(DummyValue, "name", translate("Name"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or translate("(unnamed)")
end

o = s:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or "?"
end

o = s:option(DummyValue, "filter", translate("Filter"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or "—"
end

o = s:option(DummyValue, "exclude_filter", translate("Exclude Filter"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or "—"
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
