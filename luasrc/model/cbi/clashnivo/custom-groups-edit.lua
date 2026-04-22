--[[
Edit a single `groups` UCI section.

Group type drives conditional field visibility via :depends("type", ...).
Four types (select, url-test, fallback, load-balance); smart / LightGBM is
cut. All groups emit `include-all-proxies: true` — there is no per-proxy
assignment widget. Membership is narrowed with `filter` / `exclude_filter`.

A missing/invalid sid redirects back to the list.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local uci  = luci.model.uci.cursor()
local fs   = require "luci.clashnivo"

local sid = arg[1]
local m, s, o

m = Map("clashnivo", translate("Edit Group"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/clashnivo/customize/groups")

if not sid or uci:get("clashnivo", sid) ~= "groups" then
	HTTP.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "groups")
s.anonymous = true
s.addremove = false

-- Config-file scoping. Lets the user restrict a group to one subscription.
o = s:option(ListValue, "config", translate("Applies To"))
o.description = translate("Which subscription config this group is injected into. Choose \"All\" to apply everywhere.")
o:value("all", translate("All configs"))
for _, path in ipairs(fs.glob("/etc/clashnivo/config/*")) do
	local base = fs.basename(path)
	if base then o:value(base, base) end
end
o.default = "all"

o = s:option(Value, "name", translate("Name"))
o.description = translate("Group name — must be unique within the generated config.")
o.rmempty = false
function o.validate(self, value)
	if not value or value == "" then return nil, translate("Name is required") end
	if string.find(value, '"') or string.find(value, "\n") then
		return nil, translate("Name must not contain quotes or newlines")
	end
	return value
end

o = s:option(ListValue, "type", translate("Type"))
o:value("select",       translate("Select (manual)"))
o:value("url-test",     translate("URL Test (fastest)"))
o:value("fallback",     translate("Fallback"))
o:value("load-balance", translate("Load Balance"))
o.default = "select"
o.rmempty = false

-- ----------------------------------------------------------------------------
-- Membership filters — apply to every group type. Every group emits
-- `include-all-proxies: true`, so these regexes are how a group narrows the
-- candidate pool. Leave both blank for "every proxy".
-- ----------------------------------------------------------------------------
o = s:option(Value, "filter", translate("Filter (include regex)"))
o.description = translate("Regex matched against proxy names. Proxies matching this expression are included. Leave blank to include all.")
o.rmempty = true

o = s:option(Value, "exclude_filter", translate("Exclude Filter (regex)"))
o.description = translate("Regex matched against proxy names. Proxies matching this expression are excluded.")
o.rmempty = true

o = s:option(DynamicList, "other_group", translate("Reference Other Groups"))
o.description = translate("Add other group names (or DIRECT / REJECT / GLOBAL) as members of this group. One per line.")
o.rmempty = true

-- ----------------------------------------------------------------------------
-- Health-check knobs — emitted only for types that use them.
-- ----------------------------------------------------------------------------
o = s:option(Value, "test_url", translate("Health-check URL"))
o:depends("type", "url-test")
o:depends("type", "fallback")
o:depends("type", "load-balance")
o.default = "http://cp.cloudflare.com/generate_204"
o.rmempty = true

o = s:option(Value, "test_interval", translate("Health-check Interval (seconds)"))
o:depends("type", "url-test")
o:depends("type", "fallback")
o:depends("type", "load-balance")
o.datatype = "uinteger"
o.default = "300"
o.rmempty = true

o = s:option(Value, "tolerance", translate("URL-test Tolerance (ms)"))
o:depends("type", "url-test")
o.datatype = "uinteger"
o.default = "150"
o.rmempty = true

o = s:option(ListValue, "strategy", translate("Load-balance Strategy"))
o:depends("type", "load-balance")
o:value("", translate("Default"))
o:value("round-robin")
o:value("consistent-hashing")
o:value("sticky-sessions")
o.rmempty = true

-- ----------------------------------------------------------------------------
-- Misc knobs.
-- ----------------------------------------------------------------------------
o = s:option(Flag, "disable_udp", translate("Disable UDP"))
o.rmempty = true

o = s:option(Value, "icon", translate("Icon URL"))
o.description = translate("Optional icon shown in the dashboard.")
o.rmempty = true

o = s:option(Value, "interface_name", translate("Bind Interface"))
o.description = translate("Force all proxies in this group to bind to a specific interface.")
o.rmempty = true

o = s:option(Value, "routing_mark", translate("Routing Mark"))
o.datatype = "string"
o.rmempty = true

o = s:option(TextValue, "other_parameters", translate("Extra YAML"))
o.description = translate("Raw YAML fragment appended to this group entry (advanced).")
o.rows = 4
o.rmempty = true

-- Commit / Back bar
local a = m:section(Table, {{Commit, Back}})

local b = a:option(Button, "Commit", " ")
b.inputtitle = translate("Save")
b.inputstyle = "apply"
b.write = function()
	m.uci:commit("clashnivo")
	HTTP.redirect(m.redirect)
end

b = a:option(Button, "Back", " ")
b.inputtitle = translate("Cancel")
b.inputstyle = "reset"
b.write = function()
	m.uci:revert("clashnivo", sid)
	HTTP.redirect(m.redirect)
end

return m
