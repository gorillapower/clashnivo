--[[
Edit a single `config_overwrite` UCI section (uci-schema §6).

Two sources of body content, driven by `type`:
  - `inline`: the YAML textarea on this page is wrapped as a `[YAML]` block
    and written to /etc/clashnivo/overwrite/<name> for init.d to consume.
  - `http`:   a remote URL. The cron wired up by init.d add_overwrite_cron()
    downloads to the same path on schedule. This page only edits the URL
    and auto-update knobs; the body preview below is read-only.

The init.d parser (OpenClash fork) expects [General]/[Overwrite]/[YAML]
.ini-style files. Inline bodies are wrapped to match; remote files are
stored as-is because community overwrite files usually already use the
.ini format.

A missing/invalid sid redirects back to the list.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local NXFS = require "nixio.fs"
local uci  = luci.model.uci.cursor()
local fs   = require "luci.clashnivo"

local OVERWRITE_DIR = "/etc/clashnivo/overwrite/"

local sid = arg[1]
local m, s, o

m = Map("clashnivo", translate("Edit Overwrite Source"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/clashnivo/config-overwrite")

if not sid or uci:get("clashnivo", sid) ~= "config_overwrite" then
	HTTP.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "config_overwrite")
s.anonymous = true
s.addremove = false

-- Config-file scoping. A comma-joined list of config basenames (or "all").
o = s:option(ListValue, "config", translate("Applies To"))
o.description = translate("Which subscription config this overwrite merges into. Pick \"All\" to apply everywhere.")
o:value("all", translate("All configs"))
for _, path in ipairs(fs.glob("/etc/clashnivo/config/*")) do
	local base = fs.basename(path)
	if base then o:value(base, base) end
end
o.default = "all"

o = s:option(Value, "name", translate("Name"))
o.description = translate("Identifier for this source. Used as the on-disk filename under /etc/clashnivo/overwrite/. Letters, numbers, dash, dot, underscore.")
o.rmempty = false
function o.validate(self, value, section)
	if not value or value == "" then return nil, translate("Name is required") end
	if not string.match(value, "^[%w][%w._%-]*$") then
		return nil, translate("Name may only contain letters, numbers, '-', '_', '.'")
	end
	local dup
	uci:foreach("clashnivo", "config_overwrite", function(sec)
		if sec[".name"] ~= section and sec.name == value then dup = true end
	end)
	if dup then return nil, translate("Overwrite name already exists") end
	return value
end

o = s:option(ListValue, "type", translate("Source Type"))
o:value("inline", translate("Inline YAML (edit below)"))
o:value("http",   translate("Remote URL (auto-updated)"))
o.default = "inline"
o.rmempty = false

o = s:option(Value, "order", translate("Order"))
o.description = translate("Application order (lower runs first; later sources override earlier ones).")
o.datatype = "uinteger"
o.default = "1"
o.rmempty = false

o = s:option(Value, "param", translate("Params"))
o.description = translate("Optional semicolon-delimited knobs passed to the overwrite script, e.g. KEY=value;OTHER=2.")
o.rmempty = true

-- HTTP-only fields
o = s:option(Value, "url", translate("URL"))
o:depends("type", "http")
o.description = translate("HTTP(S) URL of the overwrite file. Downloaded by cron on the schedule below.")
function o.validate(self, value, section)
	local t = m:get(section, "type") or "inline"
	if t ~= "http" then return value end
	if not value or value == "" then
		return nil, translate("URL is required when type is Remote URL")
	end
	if not string.match(value, "^https?://") then
		return nil, translate("URL must start with http:// or https://")
	end
	return value
end

o = s:option(ListValue, "update_days", translate("Update — Day of Month"))
o:depends("type", "http")
o.description = translate("Day of the month to run the auto-update. Choose \"off\" to disable scheduled updates.")
o:value("off", translate("off"))
for d = 1, 31 do o:value(tostring(d), tostring(d)) end
o.default = "off"

o = s:option(ListValue, "update_hour", translate("Update — Hour"))
o:depends("type", "http")
o.description = translate("Hour of the day (0–23) to run the auto-update.")
o:value("off", translate("off"))
for h = 0, 23 do o:value(tostring(h), tostring(h)) end
o.default = "off"

-- Inline-only: YAML body textarea. Read strips the [YAML] wrapper; write
-- adds it back so init.d's overwrite_file parser sees a [YAML] block.
local inline_body = s:option(TextValue, "__inline_body", translate("Inline YAML Body"))
inline_body:depends("type", "inline")
inline_body.description = translate("Plain YAML. Keys you set here override the same keys in the subscription config at Stage 6. Saved to /etc/clashnivo/overwrite/<name> wrapped in a [YAML] header for the init.d parser.")
inline_body.rows = 20
inline_body.wrap = "off"
inline_body.placeholder = "# Example: raise the mixed-port\n" ..
	"mixed-port: 7890\n" ..
	"\n" ..
	"dns:\n" ..
	"  enable: true\n"

local function strip_yaml_block(text)
	if not text or text == "" then return "" end
	local out, in_yaml = {}, false
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed == "[YAML]" then
			in_yaml = true
		elseif trimmed:match("^%[.*%]$") then
			in_yaml = false
		elseif in_yaml then
			table.insert(out, line)
		end
	end
	return table.concat(out, "\n")
end

function inline_body.cfgvalue(self, section)
	local name = uci:get("clashnivo", section, "name")
	if not name or name == "" then return "" end
	local body = NXFS.readfile(OVERWRITE_DIR .. name) or ""
	-- If the file contains a [YAML] section, pull just that block; otherwise
	-- treat the whole file as YAML (edge case: migrated/manual files).
	if body:match("%[YAML%]") then
		return strip_yaml_block(body)
	end
	return body
end

function inline_body.write(self, section, value)
	local t = m:get(section, "type") or "inline"
	if t ~= "inline" then return end
	local name = m:get(section, "name") or uci:get("clashnivo", section, "name")
	if not name or name == "" then return end

	value = (value or ""):gsub("\r\n?", "\n")
	NXFS.mkdirr(OVERWRITE_DIR)
	local wrapped = "[YAML]\n" .. value
	if not value:match("\n$") then wrapped = wrapped .. "\n" end
	if not NXFS.writefile(OVERWRITE_DIR .. name, wrapped) then
		m.message = translate("Failed to write ") .. OVERWRITE_DIR .. name
	end
end

function inline_body.remove(self, section)
	return inline_body.write(self, section, "")
end

-- Read-only preview for http sources: last-downloaded body, if any.
local remote_preview = s:option(DummyValue, "__remote_body", translate("Last Downloaded"))
remote_preview:depends("type", "http")
remote_preview.rawhtml = true
function remote_preview.cfgvalue(self, section)
	local name = uci:get("clashnivo", section, "name")
	if not name or name == "" then
		return "<em>" .. translate("Save the section first so the scheduled download has somewhere to land.") .. "</em>"
	end
	local path = OVERWRITE_DIR .. name
	local st = fs.stat(path)
	if not st then
		return "<em>" .. translate("No file downloaded yet. Save, then wait for the scheduled run or trigger a download manually.") .. "</em>"
	end
	local body = NXFS.readfile(path) or ""
	if #body > 4096 then body = body:sub(1, 4096) .. "\n… [truncated] …" end
	local esc = body:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return string.format(
		'<div style="font-size:0.9em;color:#666;margin-bottom:4px;">%s — %s, %s</div>'
		.. '<pre style="max-height:320px;overflow:auto;background:#f7f7f7;border:1px solid #ddd;padding:8px;">%s</pre>',
		path,
		os.date("%Y-%m-%d %H:%M:%S", st.mtime),
		fs.filesize(st.size),
		esc
	)
end

o = s:option(Flag, "enabled", translate("Enabled"))
o.default = "0"
o.rmempty = false

-- Preview button: server-side diff against the active config. Inline only.
local preview = s:option(DummyValue, "__preview", translate("Preview Diff"))
preview:depends("type", "inline")
preview.rawhtml = true
preview.cfgvalue = function(self, section)
	local url = DISP.build_url("admin/services/clashnivo/config_overwrite_preview") .. "?sid=" .. section
	return string.format([==[
<button type="button" class="cbi-button cbi-button-reload" onclick="clashnivoPreviewOverwrite('%s')">%s</button>
<pre id="clashnivo-overwrite-diff" style="display:none;max-height:420px;overflow:auto;background:#f7f7f7;border:1px solid #ddd;padding:8px;margin-top:8px;"></pre>
<script type="text/javascript">//<![CDATA[
function clashnivoPreviewOverwrite(u) {
	var pre = document.getElementById('clashnivo-overwrite-diff');
	pre.style.display = 'block';
	pre.textContent = '%s';
	XHR.get(u, null, function(x, data) {
		if (!data) { pre.textContent = '%s'; return; }
		if (data.status === 'error') { pre.textContent = '%s: ' + (data.message || ''); return; }
		pre.textContent = (data.diff && data.diff.length) ? data.diff : '%s';
	});
}
//]]></script>]==],
		url,
		translate("Preview"),
		translate("Building diff…"),
		translate("Preview request failed"),
		translate("Error"),
		translate("No differences — this overwrite would be a no-op against the active config.")
	)
end

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
