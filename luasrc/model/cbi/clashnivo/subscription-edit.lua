--[[
Edit a single config_subscribe UCI section.

The sid is passed on the URL. Subconverter fields and keyword filters are
preserved from OpenClash (per UCI schema §2). A missing/invalid sid redirects
back to the subscription list.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local uci  = luci.model.uci.cursor()

local sid = arg[1]
local m, s, o

m = Map("clashnivo", translate("Edit Subscription"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/clashnivo/subscription")

if not sid or uci:get("clashnivo", sid) ~= "config_subscribe" then
	HTTP.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "config_subscribe")
s.anonymous = true
s.addremove = false

-- Name
o = s:option(Value, "name", translate("Name"))
o.description = translate("Identifier used for the generated YAML filename (e.g. <name>.yaml). Letters, numbers, dash, dot, and underscore only.")
o.placeholder = "my-subscription"
o.rmempty = false
function o.validate(self, value)
	if not value or not string.match(value, "^[%w][%w._%-]*$") then
		return nil, translate("Name must contain only letters, numbers, dash, dot, or underscore")
	end
	return value
end

-- Address
o = s:option(Value, "address", translate("Subscription URL"))
o.template = "cbi/tvalue"
o.rows = 6
o.wrap = "off"
o.description = translate("One or more HTTP/HTTPS URLs, one per line. Multiple URLs are merged by the subconverter (if enabled) or used as fallbacks.")
o.placeholder = "https://example.com/subscription"
o.rmempty = false
function o.validate(self, value)
	if not value or value == "" then return nil, translate("URL is required") end
	value = value:gsub("\r\n?", "\n"):gsub("%c*$", "")
	for raw in value:gmatch("[^\n]+") do
		local line = raw:match("^%s*(.-)%s*$")
		if line ~= "" and not string.find(line, "^https?://") then
			return nil, translate("Only HTTP/HTTPS URLs are supported: ") .. line
		end
	end
	return value
end

-- User-Agent
o = s:option(Value, "sub_ua", translate("User-Agent"))
o.description = translate("Used for subscription downloads. Some providers gate response headers on this.")
o:value("clash.meta")
o:value("clash-verge/v1.5.1")
o:value("Clash")
o.default = "clash.meta"
o.rmempty = true

-- Subconverter block
o = s:option(Flag, "sub_convert", translate("Use Subconverter"))
o.description = translate("Pipe subscription through a subconverter service to normalise proxy formats. Adds privacy risk — your URL passes through the converter.")
o.default = "0"

o = s:option(Value, "convert_address", translate("Subconverter URL"))
o:depends("sub_convert", "1")
o:value("https://api.wcc.best/sub", "api.wcc.best")
o:value("https://api.asailor.org/sub", "api.asailor.org")
o.default = "https://api.wcc.best/sub"
o.placeholder = "https://api.wcc.best/sub"
o.rmempty = true

o = s:option(Value, "custom_template_url", translate("Template URL"))
o:depends("sub_convert", "1")
o.description = translate("External subconverter template (leave blank for the default).")
o.rmempty = true

o = s:option(ListValue, "emoji", translate("Emoji in Node Names"))
o:depends("sub_convert", "1")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"

o = s:option(ListValue, "udp", translate("UDP"))
o:depends("sub_convert", "1")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"

o = s:option(ListValue, "skip_cert_verify", translate("Skip Cert Verify"))
o:depends("sub_convert", "1")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"

o = s:option(ListValue, "sort", translate("Sort Nodes"))
o:depends("sub_convert", "1")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"

o = s:option(ListValue, "node_type", translate("Prefix Node Type"))
o:depends("sub_convert", "1")
o:value("false", translate("Disable"))
o:value("true", translate("Enable"))
o.default = "false"

o = s:option(DynamicList, "custom_params", translate("Subconverter Params"))
o.description = translate("Extra key=value params (one per line), e.g. rename=match@replace")
o:depends("sub_convert", "1")
o.rmempty = true

-- Keyword filters (apply regardless of subconverter)
o = s:option(DynamicList, "keyword", translate("Include Keywords"))
o.description = translate("Only keep proxies whose name matches at least one of these regex patterns. Leave empty to keep all.")
o.rmempty = true

o = s:option(DynamicList, "ex_keyword", translate("Exclude Keywords"))
o.description = translate("Drop proxies whose name matches any of these regex patterns.")
o.rmempty = true

o = s:option(MultiValue, "de_ex_keyword", translate("Preset Exclusions"))
o.description = translate("Drop proxies whose name contains these common subscription-metadata tokens.")
o.rmempty = true
o:value("Expire")
o:value("Traffic")
o:value("Plan")
o:value("Official")

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
