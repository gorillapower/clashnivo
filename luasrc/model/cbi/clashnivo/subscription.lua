--[[
Subscriptions page.

Per docs/architecture/ui-nav.md §Subscriptions this single page hosts four
stacked sections:
  1. Auto-update schedule (writes clashnivo.config.auto_update* keys).
  2. Subscription list — add/edit/remove + inline "Update" button per row.
  3. Manual YAML upload slot (writes into /etc/clashnivo/config/).
  4. Config file list — switch active, download, remove.

Sections 3 and 4 were previously their own top-level "Config Files" nav entry
(config.lua). They were folded in here to match the six-entry design
(ui-nav.md) where Subscriptions owns "subs + config file list + auto-update".

Scope-cut vs OpenClash:
  - No "Subscribe convert online" global tracking — per-subscription only.
  - No "Apply" button that force-rebuilds every subscription; use per-row Update.
  - No proxy-provider or rule-provider sections (schema §2, deferred post-v1).
  - No CodeMirror editor — plain TextValue only.
  - No "download running config" action.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local fs   = require "luci.clashnivo"
local uci  = require("luci.model.uci").cursor()

local CONFIG_DIR = "/etc/clashnivo/config/"

local m, s, o

-- ---------------------------------------------------------------------------
-- Map 1: subscription list + auto-update schedule
--
-- Section order: list first (the primary task is adding/editing sources), then
-- Auto Update (a secondary preference). See UX feedback 2026-04-22.
-- ---------------------------------------------------------------------------
m = Map("clashnivo", translate("Subscriptions"),
	translate("Manage subscription sources and their generated YAML config files. Each subscription entry produces one YAML under /etc/clashnivo/config/."))

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

m:append(Template("clashnivo/toolbar_show"))

-- ---------------------------------------------------------------------------
-- Map 2: upload slot — single file, writes into /etc/clashnivo/config/.
-- ---------------------------------------------------------------------------
local ful = SimpleForm("upload", translate("Upload Config"),
	translate("Upload a Mihomo YAML config. Files land in /etc/clashnivo/config/ and appear in the list below."))
-- embedded + pageaction: see custom-rules.lua for rationale.
ful.embedded = true
ful.pageaction = true
ful.reset = false
ful.submit = false

local sul = ful:section(SimpleSection, "")
local up_o = sul:option(FileUpload, "")
up_o.template = "cbi/upload"
local msg = sul:option(DummyValue, "", nil)
msg.template = "cbi/value"

local fd
HTTP.setfilehandler(function(meta, chunk, eof)
	if not fd then
		if not meta then return end
		NXFS.mkdirr(CONFIG_DIR)
		fd = nixio.open(CONFIG_DIR .. meta.file, "w")
		if not fd then msg.value = translate("Upload failed") ; return end
	end
	if chunk and fd then fd:write(chunk) end
	if eof and fd then
		fd:close()
		fd = nil
		-- Normalise .yml -> .yaml so the running pipeline sees one extension.
		if string.lower(string.sub(meta.file, -4)) == ".yml" then
			local renamed = string.sub(meta.file, 1, -5) .. ".yaml"
			fs.rename(CONFIG_DIR .. meta.file, CONFIG_DIR .. renamed)
			meta.file = renamed
		end
		msg.value = translate("Saved to ") .. CONFIG_DIR .. meta.file
	end
end)

-- ---------------------------------------------------------------------------
-- Map 3: config file list — switch / remove / download.
-- ---------------------------------------------------------------------------
local function is_yaml(name)
	local s2 = string.lower(string.sub(name or "", -5))
	return s2 == ".yaml" or string.sub(name or "", -4):lower() == ".yml"
end

-- When the active config_path points at a file that was just renamed or
-- removed, fall back to the first remaining yaml — or leave unset.
local function default_config_set(removed_name)
	local cur = fs.uci_get_config("config", "config_path") or ""
	if cur == CONFIG_DIR .. removed_name or cur == "" or not fs.access(cur) then
		local first = fs.glob(CONFIG_DIR .. "*")[1]
		if first then
			uci:set("clashnivo", "config", "config_path", CONFIG_DIR .. fs.basename(first))
		else
			uci:delete("clashnivo", "config", "config_path")
		end
		uci:commit("clashnivo")
	end
end

local rows, stat = {}, nil
for i, path in ipairs(fs.glob(CONFIG_DIR .. "*")) do
	stat = fs.stat(path)
	if stat then
		local name = fs.basename(path)
		local cur  = fs.uci_get_config("config", "config_path") or ""
		rows[i] = {
			name   = name,
			mtime  = os.date("%Y-%m-%d %H:%M:%S", stat.mtime),
			state  = (cur == CONFIG_DIR .. name) and translate("Active") or translate("Inactive"),
			size   = fs.filesize(stat.size),
		}
	end
end

local form = SimpleForm("config_file_list", translate("Config Files"))
form.embedded = true
form.pageaction = true
form.reset = false
form.submit = false

local tb = form:section(Table, rows)
tb:option(DummyValue, "state",  translate("State"))
tb:option(DummyValue, "name",   translate("Name"))
tb:option(DummyValue, "mtime",  translate("Modified"))
tb:option(DummyValue, "size",   translate("Size"))

local btn_switch = tb:option(Button, "switch", translate("Switch"))
btn_switch.inputstyle = "apply"
btn_switch.render = function(self, t, a)
	if not rows[t] or not is_yaml(rows[t].name) then a.display = "none" end
	Button.render(self, t, a)
end
btn_switch.write = function(self, t)
	if not rows[t] then return end
	uci:set("clashnivo", "config", "config_path", CONFIG_DIR .. rows[t].name)
	uci:set("clashnivo", "config", "enable", "1")
	uci:commit("clashnivo")
	SYS.call("/etc/init.d/clashnivo restart >/dev/null 2>&1 &")
	HTTP.redirect(DISP.build_url("admin", "services", "clashnivo", "subscription"))
end

local btn_rm = tb:option(Button, "remove", translate("Remove"))
btn_rm.inputstyle = "remove"
btn_rm.write = function(self, t)
	if not rows[t] then return end
	fs.unlink("/etc/clashnivo/" .. rows[t].name)
	fs.unlink(CONFIG_DIR .. rows[t].name)
	default_config_set(rows[t].name)
	table.remove(rows, t)
	HTTP.redirect(DISP.build_url("admin", "services", "clashnivo", "subscription"))
end

local btn_dl = tb:option(Button, "download", translate("Download"))
btn_dl.inputstyle = "reload"
btn_dl.write = function(self, t)
	if not rows[t] then return end
	local path = CONFIG_DIR .. rows[t].name
	local handle = nixio.open(path, "r")
	if not handle then return end
	HTTP.header("Content-Disposition", 'attachment; filename="' .. rows[t].name .. '"')
	HTTP.prepare_content("application/octet-stream")
	while true do
		local block = handle:read(nixio.const.buffersize)
		if (not block) or (#block == 0) then break end
		HTTP.write(block)
	end
	handle:close()
	HTTP.close()
end

return m, ful, form
