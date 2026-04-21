--[[
Custom rules + rule providers (Epic 3c).

One page with three stacked forms:
  1. Master toggle (clashnivo.config.enable_custom_clash_rules) + rule_provider
     table (section type `rule_provider`, uci-schema.md §9). Add opens the
     edit page; one row per declared provider.
  2. File manager for local rule-set bodies under /etc/clashnivo/rule_provider/.
     These files back `rule_provider` entries whose `type = file`.
  3. Custom rules editor — one rule per line, backed by
     /etc/clashnivo/custom/clashnivo_custom_rules.list (YAML `rules:` array).
     yml_rules_change.sh already consumes that file at Stage 5; this form just
     gives users a GUI over it.

Scope cuts vs OpenClash:
  - OpenClash ships a raw file editor for rule-provider YAML bodies. We model
    providers as declarative UCI sections (one per provider) and keep the file
    manager only for the uploaded body files.
  - No per-rule validation UI yet — validation runs only on save (parse +
    target-reference check) and surfaces as a section error message.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local NXFS = require "nixio.fs"
local fs   = require "luci.clashnivo"

local RULES_FILE   = "/etc/clashnivo/custom/clashnivo_custom_rules.list"
local PROVIDER_DIR = "/etc/clashnivo/rule_provider/"

local m, s, o

-- ---------------------------------------------------------------------------
-- Form 1: master toggle + rule_provider list
-- ---------------------------------------------------------------------------
m = Map("clashnivo", translate("Custom Rules"),
	translate("Define rule-set providers and additional Clash rules. Custom rules are prepended to the subscription's rule list so they always take precedence."))
m.pageaction = false

s = m:section(NamedSection, "config", "clashnivo", translate("Master Switch"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enable_custom_clash_rules", translate("Enable Custom Rules"))
o.description = translate("When enabled, rule-provider entries and the rule list below are merged into the active config at startup. Leave off to ship the subscription as-is.")
o.default = "0"
o.rmempty = false

-- rule_provider table
s = m:section(TypedSection, "rule_provider", translate("Rule Providers"),
	translate("Each entry becomes an item under Mihomo's rule-providers: block. Reference them from a rule as RULE-SET,<name>,<target>."))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"
s.extedit = DISP.build_url("admin/services/clashnivo/custom-rules-edit/%s")

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
	return Value.cfgvalue(self, section) or "http"
end

o = s:option(DummyValue, "behavior", translate("Behavior"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or "classical"
end

o = s:option(DummyValue, "format", translate("Format"))
function o.cfgvalue(self, section)
	return Value.cfgvalue(self, section) or "yaml"
end

o = s:option(DummyValue, "url", translate("Source"))
function o.cfgvalue(self, section)
	local t = self.map:get(section, "type") or "http"
	if t == "file" then
		local name = self.map:get(section, "name") or ""
		return "file:" .. name
	end
	local u = self.map:get(section, "url") or "—"
	if #u > 48 then u = string.sub(u, 1, 45) .. "…" end
	return u
end

o = s:option(DummyValue, "config", translate("Applies To"))
function o.cfgvalue(self, section)
	local v = self.map:get(section, "config")
	if type(v) == "table" then v = table.concat(v, ", ") end
	if not v or v == "" then return "all" end
	return v
end

m:append(Template("clashnivo/toolbar_show"))

-- ---------------------------------------------------------------------------
-- Form 2: local rule-set file manager
-- ---------------------------------------------------------------------------
local upload_form = SimpleForm("rule_provider_upload",
	translate("Upload Rule-Set File"),
	translate("Upload a local rule-set body. Files are stored in /etc/clashnivo/rule_provider/ and referenced by rule_provider entries whose type is \"file\"."))
upload_form.reset = false
upload_form.submit = false

local sul = upload_form:section(SimpleSection, "")
local up  = sul:option(FileUpload, "")
up.template = "cbi/upload"
local msg = sul:option(DummyValue, "", nil)
msg.template = "cbi/value"

local fd
HTTP.setfilehandler(function(meta, chunk, eof)
	if not fd then
		if not meta or not meta.file then return end
		-- Reject anything with a path separator to prevent writes outside
		-- /etc/clashnivo/rule_provider/.
		if string.find(meta.file, "/", 1, true) or string.find(meta.file, "\\", 1, true) then
			msg.value = translate("Upload rejected: file name must not contain path separators")
			return
		end
		NXFS.mkdirr(PROVIDER_DIR)
		fd = nixio.open(PROVIDER_DIR .. meta.file, "w")
		if not fd then
			msg.value = translate("Upload failed")
			return
		end
	end
	if chunk and fd then fd:write(chunk) end
	if eof and fd then
		fd:close()
		fd = nil
		msg.value = translate("Saved to ") .. PROVIDER_DIR .. meta.file
	end
end)

-- Enumerate current files.
local rows = {}
for i, path in ipairs(fs.glob(PROVIDER_DIR .. "*")) do
	local st = fs.stat(path)
	if st and st.type == "regular" then
		rows[i] = {
			name  = fs.basename(path),
			mtime = os.date("%Y-%m-%d %H:%M:%S", st.mtime),
			size  = fs.filesize(st.size),
		}
	end
end

local files_form = SimpleForm("rule_provider_files", translate("Local Rule-Set Files"))
files_form.reset = false
files_form.submit = false

local tb = files_form:section(Table, rows)
tb:option(DummyValue, "name",  translate("File Name"))
tb:option(DummyValue, "mtime", translate("Modified"))
tb:option(DummyValue, "size",  translate("Size"))

local btn_dl = tb:option(Button, "download", translate("Download"))
btn_dl.inputstyle = "reload"
btn_dl.write = function(self, t)
	local row = rows[t]
	if not row then return end
	local path = PROVIDER_DIR .. row.name
	local h = nixio.open(path, "r")
	if not h then return end
	HTTP.header("Content-Disposition", 'attachment; filename="' .. row.name .. '"')
	HTTP.prepare_content("application/octet-stream")
	while true do
		local block = h:read(nixio.const.buffersize)
		if (not block) or (#block == 0) then break end
		HTTP.write(block)
	end
	h:close()
	HTTP.close()
end

local btn_rm = tb:option(Button, "remove", translate("Remove"))
btn_rm.inputstyle = "remove"
btn_rm.write = function(self, t)
	local row = rows[t]
	if not row then return end
	fs.unlink(PROVIDER_DIR .. row.name)
	table.remove(rows, t)
	HTTP.redirect(DISP.build_url("admin", "services", "clashnivo", "custom-rules"))
end

-- ---------------------------------------------------------------------------
-- Form 3: custom rules editor (TextValue over clashnivo_custom_rules.list)
-- ---------------------------------------------------------------------------

-- Read the current rules list file. Accepts either:
--   - plain-text "one rule per line"
--   - YAML with a top-level `rules:` array
-- and always returns the content as a newline-joined string.
local function load_rules_text()
	local body = NXFS.readfile(RULES_FILE)
	if not body or body == "" then return "" end
	-- If it looks like YAML, strip the `rules:` header + `- ` list prefix.
	local lines, in_rules = {}, false
	for line in (body .. "\n"):gmatch("([^\n]*)\n") do
		if in_rules then
			local item = line:match("^%s*%-%s+(.+)$")
			if item then
				item = item:gsub("^['\"]", ""):gsub("['\"]$", "")
				table.insert(lines, item)
			elseif not line:match("^%s*$") and not line:match("^%s") then
				-- Top-level key that ends the rules block.
				in_rules = false
			end
		elseif line:match("^%s*rules%s*:%s*$") then
			in_rules = true
		else
			-- No YAML wrapper: treat every non-comment line as a rule.
			if not line:match("^%s*$") and not line:match("^%s*#") then
				table.insert(lines, line:gsub("^%s+", ""):gsub("%s+$", ""))
			end
		end
	end
	return table.concat(lines, "\n")
end

-- Rule format + target validation. Returns (true) or (false, errmsg).
-- Accepts targets that are:
--   built-in keywords (DIRECT, REJECT, REJECT-DROP, PASS, GLOBAL, COMPATIBLE)
--   a declared group/server name (from UCI)
--   a declared sub-rule name (we don't parse sub-rules; allow anything else)
local BUILT_IN = {
	DIRECT = true, REJECT = true, ["REJECT-DROP"] = true,
	PASS = true, GLOBAL = true, COMPATIBLE = true,
}
local RULE_TYPES = {
	["DOMAIN"] = true, ["DOMAIN-SUFFIX"] = true, ["DOMAIN-KEYWORD"] = true,
	["DOMAIN-WILDCARD"] = true, ["DOMAIN-REGEX"] = true,
	["GEOSITE"] = true, ["GEOIP"] = true, ["IP-ASN"] = true,
	["IP-CIDR"] = true, ["IP-CIDR6"] = true, ["SRC-IP-CIDR"] = true,
	["IP-SUFFIX"] = true, ["SRC-IP-SUFFIX"] = true, ["SRC-IP-ASN"] = true,
	["DST-PORT"] = true, ["SRC-PORT"] = true, ["IN-PORT"] = true,
	["IN-TYPE"] = true, ["IN-USER"] = true, ["IN-NAME"] = true,
	["PROCESS-NAME"] = true, ["PROCESS-NAME-REGEX"] = true,
	["PROCESS-PATH"] = true, ["PROCESS-PATH-REGEX"] = true,
	["UID"] = true, ["NETWORK"] = true, ["DSCP"] = true,
	["RULE-SET"] = true, ["SUB-RULE"] = true,
	["AND"] = true, ["OR"] = true, ["NOT"] = true,
	["MATCH"] = true, ["FINAL"] = true,
}

local function known_targets()
	local t = {}
	for k in pairs(BUILT_IN) do t[k] = true end
	local uci = require("luci.model.uci").cursor()
	uci:foreach("clashnivo", "groups", function(sec)
		if sec.name and sec.name ~= "" then t[sec.name] = true end
	end)
	uci:foreach("clashnivo", "servers", function(sec)
		if sec.name and sec.name ~= "" then t[sec.name] = true end
	end)
	return t
end

local function provider_names()
	local t = {}
	local uci = require("luci.model.uci").cursor()
	uci:foreach("clashnivo", "rule_provider", function(sec)
		if sec.name and sec.name ~= "" then t[sec.name] = true end
	end)
	return t
end

local function validate_rule(rule, targets, providers)
	local parts = {}
	for p in (rule .. ","):gmatch("([^,]*),") do table.insert(parts, p:match("^%s*(.-)%s*$") or "") end
	while #parts > 0 and parts[#parts] == "" do table.remove(parts) end
	if #parts == 0 then return false, "empty rule" end

	local rtype = string.upper(parts[1])
	if not RULE_TYPES[rtype] then return false, "unknown rule type: " .. parts[1] end

	-- MATCH/FINAL: `MATCH,<target>`
	if rtype == "MATCH" or rtype == "FINAL" then
		if #parts < 2 then return false, rtype .. " requires a target" end
		if not targets[parts[2]] then
			return false, rtype .. " target not found: " .. parts[2]
		end
		return true
	end

	if #parts < 3 then return false, rtype .. " requires 'type,body,target'" end

	-- Drop trailing suffix modifiers (no-resolve, src) before target check.
	local target_idx = #parts
	local last = string.lower(parts[target_idx])
	if last == "no-resolve" or last == "src" then
		target_idx = target_idx - 1
		if target_idx < 3 then return false, "rule missing target before modifier" end
	end
	local target = parts[target_idx]

	if rtype == "RULE-SET" then
		local provider = parts[2]
		if not providers[provider] then
			return false, "RULE-SET references unknown provider: " .. provider
		end
	end

	if not targets[target] then
		return false, "unknown target: " .. target
	end

	return true
end

-- Convert a newline-separated text block into a YAML `rules:` file body.
local function rules_to_yaml(text)
	local out = { "rules:" }
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local v = line:gsub("^%s+", ""):gsub("%s+$", "")
		if v ~= "" and not v:match("^#") then
			-- YAML-safe single-quoting.
			local esc = v:gsub("'", "''")
			table.insert(out, "  - '" .. esc .. "'")
		end
	end
	return table.concat(out, "\n") .. "\n"
end

local rules_form = SimpleForm("custom_rules", translate("Custom Rules"),
	translate("One rule per line. Comments with '#'. Order matters — the list is prepended to the subscription's rules so the first match wins."))
rules_form.reset = false

local rs = rules_form:section(SimpleSection, "")
local rt = rs:option(TextValue, "rules_text")
rt.rows = 20
rt.wrap = "off"
rt.cfgvalue = function() return load_rules_text() end

-- Validate + write on submit. Runs per-section, but SimpleSection has exactly
-- one, so this fires once. Errors are surfaced via rules_form.message.
rt.write = function(self, section, value)
	value = (value or ""):gsub("\r\n?", "\n")

	local targets, providers = known_targets(), provider_names()
	local errors = {}
	local line_no = 0
	for line in (value .. "\n"):gmatch("([^\n]*)\n") do
		line_no = line_no + 1
		local v = line:gsub("^%s+", ""):gsub("%s+$", "")
		if v ~= "" and not v:match("^#") then
			local ok, err = validate_rule(v, targets, providers)
			if not ok then
				table.insert(errors, "line " .. line_no .. ": " .. err)
			end
		end
	end

	if #errors > 0 then
		rules_form.message = table.concat(errors, "\n")
		return
	end

	NXFS.mkdirr("/etc/clashnivo/custom")
	if not NXFS.writefile(RULES_FILE, rules_to_yaml(value)) then
		rules_form.message = translate("Failed to write ") .. RULES_FILE
		return
	end
	rules_form.message = translate("Saved. Restart the service to apply.")
end

-- When the user clears the textarea, LuCI calls `.remove` instead of
-- `.write`. Route both through the same save path so an intentional empty
-- list is honoured.
rt.remove = function(self, section)
	return rt.write(self, section, "")
end

return m, upload_form, files_form, rules_form
