--[[
Config file manager: lists /etc/clashnivo/config/*.yaml with switch /
rename / remove actions, plus a single manual YAML upload slot.

Scope-cut vs OpenClash:
  - No proxy-provider or rule-provider sections (schema §2, deferred post-v1).
  - No core-binary upload here (Epic 4 owns core install).
  - No backup-file restore upload (not in v1 scope).
  - No CodeMirror editor — plain TextValue only (syntax-highlight editor is
    Epic 3d work).
  - No "download running config" action — the running config lives under
    /etc/clashnivo/<name>.yaml after assembly; Epic 3 adds a viewer.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local fs   = require "luci.clashnivo"
local uci  = require("luci.model.uci").cursor()

local CONFIG_DIR = "/etc/clashnivo/config/"
local CHIF = "0"

local function is_yaml(name)
	local s = string.lower(string.sub(name or "", -5))
	return s == ".yaml" or string.sub(name or "", -4):lower() == ".yml"
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

-- ---------------------------------------------------------------------------
-- Upload slot: single file, writes into /etc/clashnivo/config/.
-- ---------------------------------------------------------------------------
local ful = SimpleForm("upload", translate("Upload Config"),
	translate("Upload a Mihomo YAML config. Files land in /etc/clashnivo/config/ and appear in the list below."))
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
		CHIF = "1"
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
-- File list.
-- ---------------------------------------------------------------------------
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
form.reset = false
form.submit = false

local tb = form:section(Table, rows)
tb:option(DummyValue, "state",  translate("State"))
tb:option(DummyValue, "name",   translate("Name"))
tb:option(DummyValue, "mtime",  translate("Modified"))
tb:option(DummyValue, "size",   translate("Size"))

-- Switch active
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
	HTTP.redirect(DISP.build_url("admin", "services", "clashnivo", "config"))
end

-- Remove
local btn_rm = tb:option(Button, "remove", translate("Remove"))
btn_rm.inputstyle = "remove"
btn_rm.write = function(self, t)
	if not rows[t] then return end
	fs.unlink("/etc/clashnivo/" .. rows[t].name)
	fs.unlink(CONFIG_DIR .. rows[t].name)
	default_config_set(rows[t].name)
	table.remove(rows, t)
	HTTP.redirect(DISP.build_url("admin", "services", "clashnivo", "config"))
end

-- Download
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

return ful, form
