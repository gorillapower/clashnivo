--[[
Subscription list page.

Renders two stacked forms:
  1. Auto-update schedule (writes clashnivo.config.auto_update* keys).
  2. Tabular subscription list with add/edit/remove + inline "Update" button
     that triggers clashnivo.sh for that subscription.

Scope-cut vs OpenClash:
  - No "Subscribe convert online" global tracking — per-subscription only.
  - No "Apply" button that force-rebuilds every subscription; use per-row Update.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local SYS  = require "luci.sys"
local fs   = require "luci.clashnivo"

local m, s, o

m = Map("clashnivo", translate("Subscriptions"),
	translate("Manage subscription sources. Each entry produces one YAML config under /etc/clashnivo/config/."))
m.pageaction = false

-- Auto-update schedule (writes singleton keys).
s = m:section(NamedSection, "config", "clashnivo", translate("Auto Update"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "auto_update", translate("Auto Update"))
o.description = translate("Refresh subscriptions on a schedule.")
o.default = "0"

o = s:option(ListValue, "config_auto_update_mode", translate("Update Mode"))
o:depends("auto_update", "1")
o:value("0", translate("Scheduled"))
o:value("1", translate("Loop"))
o.default = "0"
o.rmempty = true

o = s:option(ListValue, "config_update_week_time", translate("Day of Week"))
o:depends("config_auto_update_mode", "0")
o:value("*", translate("Every Day"))
o:value("1", translate("Monday"))
o:value("2", translate("Tuesday"))
o:value("3", translate("Wednesday"))
o:value("4", translate("Thursday"))
o:value("5", translate("Friday"))
o:value("6", translate("Saturday"))
o:value("0", translate("Sunday"))
o.default = "*"
o.rmempty = true

o = s:option(ListValue, "auto_update_time", translate("Hour of Day"))
o:depends("config_auto_update_mode", "0")
for h = 0, 23 do o:value(tostring(h), string.format("%02d:00", h)) end
o.default = "0"
o.rmempty = true

o = s:option(Value, "config_update_interval", translate("Interval (minutes)"))
o:depends("config_auto_update_mode", "1")
o.datatype = "uinteger"
o.default = "60"
o.rmempty = true

-- Subscription list (tabular).
s = m:section(TypedSection, "config_subscribe", translate("Subscription List"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = DISP.build_url("admin/services/clashnivo/subscription-edit/%s")

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
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("(unnamed)")
end

o = s:option(DummyValue, "name", translate("Subscription Info"))
o.template = "clashnivo/sub_info_show"

o = s:option(DummyValue, "name", translate("Update"))
o.template = "clashnivo/update_config"

m:append(Template("clashnivo/toolbar_show"))

return m
