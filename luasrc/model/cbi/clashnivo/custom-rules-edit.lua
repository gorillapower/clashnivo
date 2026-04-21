--[[
Edit a single `rule_provider` UCI section (uci-schema.md §9).

Type drives conditional visibility:
  - `http` needs a URL and allows an interval.
  - `file` picks one of the uploaded files under /etc/clashnivo/rule_provider/.

A missing/invalid sid redirects back to the list.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local uci  = luci.model.uci.cursor()
local fs   = require "luci.clashnivo"

local PROVIDER_DIR = "/etc/clashnivo/rule_provider/"

local sid = arg[1]
local m, s, o

m = Map("clashnivo", translate("Edit Rule Provider"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/clashnivo/custom-rules")

if not sid or uci:get("clashnivo", sid) ~= "rule_provider" then
	HTTP.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "rule_provider")
s.anonymous = true
s.addremove = false

-- Config-file scoping. Lets the user restrict a provider to one subscription.
o = s:option(ListValue, "config", translate("Applies To"))
o.description = translate("Which subscription config this provider is injected into. Choose \"All\" to apply everywhere.")
o:value("all", translate("All configs"))
for _, path in ipairs(fs.glob("/etc/clashnivo/config/*")) do
	local base = fs.basename(path)
	if base then o:value(base, base) end
end
o.default = "all"

o = s:option(Value, "name", translate("Name"))
o.description = translate("Provider name — referenced from rules as RULE-SET,<name>,<target>. Must be unique within the generated config.")
o.rmempty = false
function o.validate(self, value, section)
	if not value or value == "" then return nil, translate("Name is required") end
	if not string.match(value, "^[%w_%-%.]+$") then
		return nil, translate("Name may only contain letters, numbers, '-', '_', '.'")
	end
	-- Uniqueness check across rule_provider sections.
	local dup
	uci:foreach("clashnivo", "rule_provider", function(sec)
		if sec[".name"] ~= section and sec.name == value then dup = true end
	end)
	if dup then return nil, translate("Provider name already exists") end
	return value
end

o = s:option(ListValue, "type", translate("Source Type"))
o:value("http", translate("Remote URL (auto-updated)"))
o:value("file", translate("Local file (uploaded)"))
o.default = "http"
o.rmempty = false

o = s:option(ListValue, "behavior", translate("Behavior"))
o.description = translate("Must match the rule-set body's format. `domain` for domain-only sets, `ipcidr` for CIDR lists, `classical` for Clash-rule-syntax sets.")
o:value("classical")
o:value("domain")
o:value("ipcidr")
o.default = "classical"
o.rmempty = false

o = s:option(ListValue, "format", translate("Format"))
o:value("yaml")
o:value("text")
o:value("mrs")
o.default = "yaml"
o.rmempty = false

-- HTTP-only
o = s:option(Value, "url", translate("URL"))
o:depends("type", "http")
o.description = translate("HTTP(S) URL of the rule-set body.")
function o.validate(self, value, section)
	local t = m:get(section, "type") or "http"
	if t ~= "http" then return value end
	if not value or value == "" then
		return nil, translate("URL is required when type is Remote")
	end
	if not string.match(value, "^https?://") then
		return nil, translate("URL must start with http:// or https://")
	end
	return value
end

o = s:option(Value, "interval", translate("Refresh Interval (seconds)"))
o:depends("type", "http")
o.datatype = "uinteger"
o.default = "86400"
o.rmempty = true

o = s:option(Value, "size_limit", translate("Size Limit (bytes)"))
o:depends("type", "http")
o.description = translate("Reject downloaded bodies larger than this. 0 means unlimited.")
o.datatype = "uinteger"
o.default = "0"
o.rmempty = true

o = s:option(Value, "proxy", translate("Fetch Through Proxy"))
o:depends("type", "http")
o.description = translate("Optional. Route the rule-set download through a named proxy or group (leave blank for direct).")
o.rmempty = true

-- File-only
o = s:option(ListValue, "path", translate("Local File"))
o:depends("type", "file")
o.description = translate("Upload files from the Custom Rules page, then pick one here.")
o:value("", translate("-- select --"))
for _, p in ipairs(fs.glob(PROVIDER_DIR .. "*")) do
	local name = fs.basename(p)
	if name then o:value(name, name) end
end
function o.validate(self, value, section)
	local t = m:get(section, "type") or "http"
	if t ~= "file" then return value end
	if not value or value == "" then
		return nil, translate("Pick a local rule-set file, or upload one first")
	end
	if not fs.access(PROVIDER_DIR .. value) then
		return nil, translate("File does not exist: ") .. value
	end
	return value
end

o = s:option(Flag, "enabled", translate("Enabled"))
o.default = "1"
o.rmempty = false

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
