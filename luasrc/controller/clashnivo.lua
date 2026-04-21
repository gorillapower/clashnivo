--[[
Controller for luci-app-clashnivo. Forked from luci-app-openclash controller
and trimmed heavily.

Scope status:
  - Epic 1 (overview + settings shell + log viewer) — implemented.
  - Epic 2 (subscription mgmt + config file manager) — implemented.
  - Epic 3 (custom servers/groups/rules/overwrite) — routes stubbed.
  - Epic 4 (core binary mgmt) — routes stubbed.
  - Epic 5 (diagnostics, flush DNS) — routes stubbed.
  - OpenClash features cut in v1 (streaming unlock, smart/LightGBM, chnroute,
    IPv6, dashboard swap, developer/debug panels) get no route.
  - UCI namespace is `clashnivo`. Per uci-schema.md Q1, `operation_mode` is
    canonical; `en_mode` is not used.
]]--

module("luci.controller.clashnivo", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/clashnivo") then
		return
	end

	local page

	page = entry({"admin", "services", "clashnivo"}, alias("admin", "services", "clashnivo", "overview"), _("Clash Nivo"), 51)
	page.dependent = true
	page.acl_depends = { "luci-app-clashnivo" }

	-- Epic 1 pages
	entry({"admin", "services", "clashnivo", "overview"},     form("clashnivo/overview"),     _("Overview"),      10).leaf = true
	entry({"admin", "services", "clashnivo", "settings"},     cbi("clashnivo/settings"),      _("Settings"),      20).leaf = true
	-- Epic 2 pages
	entry({"admin", "services", "clashnivo", "subscription"},      cbi("clashnivo/subscription"),      _("Subscriptions"), 30).leaf = true
	entry({"admin", "services", "clashnivo", "subscription-edit"}, cbi("clashnivo/subscription-edit"), nil).leaf = true
	entry({"admin", "services", "clashnivo", "config"},            cbi("clashnivo/config"),            _("Config Files"),  40).leaf = true
	entry({"admin", "services", "clashnivo", "log"},               cbi("clashnivo/log"),               _("Logs"),          90).leaf = true

	-- Epic 1 AJAX endpoints (implemented)
	entry({"admin", "services", "clashnivo", "status"},            call("action_status")).leaf = true
	entry({"admin", "services", "clashnivo", "service_toggle"},    call("action_service_toggle")).leaf = true
	entry({"admin", "services", "clashnivo", "startlog"},          call("action_start")).leaf = true
	entry({"admin", "services", "clashnivo", "toolbar_show"},      call("action_toolbar_show"))
	entry({"admin", "services", "clashnivo", "toolbar_show_sys"},  call("action_toolbar_show_sys"))
	entry({"admin", "services", "clashnivo", "op_mode"},           call("action_op_mode"))
	entry({"admin", "services", "clashnivo", "switch_mode"},       call("action_switch_mode"))
	entry({"admin", "services", "clashnivo", "rule_mode"},         call("action_rule_mode"))
	entry({"admin", "services", "clashnivo", "switch_rule_mode"},  call("action_switch_rule_mode"))
	entry({"admin", "services", "clashnivo", "log_level"},         call("action_log_level"))
	entry({"admin", "services", "clashnivo", "switch_log"},        call("action_switch_log"))
	entry({"admin", "services", "clashnivo", "refresh_log"},       call("action_refresh_log"))
	entry({"admin", "services", "clashnivo", "del_log"},           call("action_del_log"))
	entry({"admin", "services", "clashnivo", "del_start_log"},     call("action_del_start_log"))
	entry({"admin", "services", "clashnivo", "close_all_connection"}, call("action_close_all_connection"))
	entry({"admin", "services", "clashnivo", "reload_firewall"},   call("action_reload_firewall"))
	entry({"admin", "services", "clashnivo", "config_name"},       call("action_config_name"))
	entry({"admin", "services", "clashnivo", "switch_config"},     call("action_switch_config"))

	-- Epic 2 (subscription management) AJAX endpoints
	entry({"admin", "services", "clashnivo", "sub_info_get"},         call("action_sub_info_get")).leaf = true
	entry({"admin", "services", "clashnivo", "add_subscription"},     call("action_add_subscription")).leaf = true
	entry({"admin", "services", "clashnivo", "update_config"},        call("action_update_config")).leaf = true
	entry({"admin", "services", "clashnivo", "get_subscribe_data"},   call("action_get_subscribe_data")).leaf = true

	-- Epic 3 (custom servers/groups/rules/overwrite) — routes stubbed
	entry({"admin", "services", "clashnivo", "overwrite_subscribe_info"}, call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "overwrite_file_list"},  call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "delete_overwrite_file"}, call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "upload_overwrite"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "upload_config"},        call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "config_file_list"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "config_file_read"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "config_file_save"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "create_file"},          call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "rename_file"},          call("stub_not_implemented"))

	-- Epic 4 (core binary management) — routes stubbed
	entry({"admin", "services", "clashnivo", "check_core"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "core_download"},  call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "coreupdate"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "lastversion"},    call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "get_last_version"}, call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "update"},         call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "update_info"},    call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "update_ma"},      call("stub_not_implemented"))

	-- Epic 5 (polish & hardening) — routes stubbed
	entry({"admin", "services", "clashnivo", "flush_dns_cache"}, call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "download_rule"},  call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "myip_check"},     call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "website_check"},  call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "diag_connection"}, call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "diag_dns"},       call("stub_not_implemented"))
	entry({"admin", "services", "clashnivo", "gen_debug_logs"}, call("stub_not_implemented"))
end

local fs = require "luci.clashnivo"
local json = require "luci.jsonc"
local uci = require("luci.model.uci").cursor()

local function is_running()
	return luci.sys.call("pidof mihomo >/dev/null 2>&1") == 0 or luci.sys.call("pidof clash >/dev/null 2>&1") == 0
end

local function cn_port()
	return fs.uci_get_config("config", "cn_port") or "9190"
end

local function mode()
	return fs.uci_get_config("config", "operation_mode")
end

local function daip()
	return fs.lanip()
end

local function dase()
	return fs.uci_get_config("config", "dashboard_password")
end

local function db_foward_domain()
	return fs.uci_get_config("config", "dashboard_forward_domain")
end

local function db_foward_ssl()
	return fs.uci_get_config("config", "dashboard_forward_ssl") or 0
end

local function startlog()
	local info = ""
	if fs.access("/tmp/clashnivo_start.log") then
		info = luci.sys.exec("sed -n '$p' /tmp/clashnivo_start.log 2>/dev/null")
	end
	return info
end

-- Minimal log line pass-through. OpenClash's version walks 【】 segments
-- for bilingual substitution; Clash Nivo is English-first, so this is a
-- no-op that guarantees a non-nil string and stamps missing timestamps.
local function trans_line(data)
	if data == nil or data == "" then
		return ""
	end
	local has_timestamp = string.len(data) >= 19 and string.match(string.sub(data, 1, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d")
	if not has_timestamp then
		return os.date("%Y-%m-%d %H:%M:%S") .. " [Info] " .. data
	end
	return data
end

function stub_not_implemented()
	luci.http.status(501, "Not Implemented")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		status = "error",
		message = "Not implemented yet in this release"
	})
end

function action_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		clash = uci:get("clashnivo", "config", "enable") == "1",
		running = is_running(),
		daip = daip(),
		dase = dase(),
		db_foward_domain = db_foward_domain(),
		db_forward_ssl = db_foward_ssl(),
		cn_port = cn_port(),
		dashboard_type = fs.uci_get_config("config", "dashboard_type") or "zashboard",
		metacubexd = fs.isdirectory("/usr/share/clashnivo/ui/metacubexd"),
		zashboard = fs.isdirectory("/usr/share/clashnivo/ui/zashboard"),
	})
end

function action_start()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		startlog = startlog();
	})
end

function action_op_mode()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		op_mode = fs.uci_get_config("config", "operation_mode") or "fake-ip";
	})
end

function action_switch_mode()
	local current = fs.uci_get_config("config", "operation_mode") or "fake-ip"
	-- Caller may pass an explicit target via ?mode=…; otherwise fall back to
	-- legacy toggle behaviour (OpenClash flipped between fake-ip and redir-host).
	local target = luci.http.formvalue("mode")
	if target ~= "fake-ip" and target ~= "redir-host" then
		target = (current == "redir-host") and "fake-ip" or "redir-host"
	end
	if target ~= current then
		uci:set("clashnivo", "config", "operation_mode", target)
		uci:commit("clashnivo")
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		previous = current,
		mode = target,
		restart_required = (target ~= current);
	})
end

function action_service_toggle()
	local action = luci.http.formvalue("action")
	if action ~= "start" and action ~= "stop" and action ~= "restart" then
		luci.http.status(400, "Bad action")
		return
	end
	if action == "start" then
		uci:set("clashnivo", "config", "enable", "1")
		uci:commit("clashnivo")
		luci.sys.call("/etc/init.d/clashnivo start >/dev/null 2>&1 &")
	elseif action == "stop" then
		uci:set("clashnivo", "config", "enable", "0")
		uci:commit("clashnivo")
		luci.sys.call("/etc/init.d/clashnivo stop >/dev/null 2>&1 &")
	else
		luci.sys.call("/etc/init.d/clashnivo restart >/dev/null 2>&1 &")
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({ status = "ok", action = action })
end

function action_rule_mode()
	local proxy_mode, info
	if is_running() then
		local _daip = daip()
		local _dase = dase() or ""
		local _cn_port = cn_port()
		if _daip and _cn_port then
			info = json.parse(luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs', _dase, _daip, _cn_port)))
		end
	end
	if info and info["mode"] then
		proxy_mode = info["mode"]
	else
		proxy_mode = fs.uci_get_config("config", "proxy_mode") or "rule"
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		mode = proxy_mode;
	})
end

function action_switch_rule_mode()
	local new_mode = luci.http.formvalue("rule_mode")
	if not new_mode then
		luci.http.status(500, "Missing parameters")
		return
	end
	local info = ""
	if is_running() then
		local _daip = daip()
		local _dase = dase() or ""
		local _cn_port = cn_port()
		if not _daip or not _cn_port then
			luci.http.status(500, "Switch failed")
			return
		end
		info = luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"mode\": \"%s\"}\'', _dase, _daip, _cn_port, new_mode))
		if info ~= "" then
			luci.http.status(500, "Switch failed")
		end
	end
	uci:set("clashnivo", "config", "proxy_mode", new_mode)
	uci:commit("clashnivo")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		info = info;
	})
end

function action_log_level()
	local level, info
	if is_running() then
		local _daip = daip()
		local _dase = dase() or ""
		local _cn_port = cn_port()
		if _daip and _cn_port then
			info = json.parse(luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/configs', _dase, _daip, _cn_port)))
		end
	end
	if info and info["log-level"] then
		level = info["log-level"]
	else
		level = fs.uci_get_config("config", "log_level") or "info"
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		log_level = level;
	})
end

function action_switch_log()
	local info = ""
	local level = luci.http.formvalue("log_level")
	if not level then
		luci.http.status(500, "Missing parameters")
		return
	end
	if is_running() then
		local _daip = daip()
		local _dase = dase() or ""
		local _cn_port = cn_port()
		if not _daip or not _cn_port then
			luci.http.status(500, "Switch failed")
			return
		end
		info = luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XPATCH http://"%s":"%s"/configs -d \'{\"log-level\": \"%s\"}\'', _dase, _daip, _cn_port, level))
		if info ~= "" then
			luci.http.status(500, "Switch failed")
		end
	end
	uci:set("clashnivo", "config", "log_level", level)
	uci:commit("clashnivo")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		info = info;
	})
end

-- Byte-rate pretty-printer for toolbar traffic readout.
local function rate(e)
	local t = 1
	local a = {' B/S', ' KB/S', ' MB/S', ' GB/S', ' TB/S', ' PB/S'}
	if (e <= 1024) then
		return e .. a[1]
	end
	repeat
		e = e / 1024
		t = t + 1
	until (e <= 1024)
	return string.format("%.1f", e) .. a[t]
end

function action_toolbar_show_sys()
	local cpu = "0"
	local load_avg = "0"
	local cpu_count = luci.sys.exec("grep -c ^processor /proc/cpuinfo 2>/dev/null"):gsub("\n", "") or 1

	local pid = luci.sys.exec("pgrep -f '^[^ ]*mihomo' | head -1 | tr -d '\n' 2>/dev/null")
	if not pid or pid == "" then
		pid = luci.sys.exec("pgrep -f '^[^ ]*clash' | head -1 | tr -d '\n' 2>/dev/null")
	end

	if pid and pid ~= "" then
		cpu = luci.sys.exec(string.format([[
		top -b -n1 | awk -v pid="%s" '
			BEGIN { cpu_col=0; }
			$0 ~ /%%CPU/ {
				for(i=1;i<=NF;i++) if($i=="%%CPU") cpu_col=i;
				next
			}
			cpu_col>0 && $1==pid { print $cpu_col }
		'
		]], pid))
		cpu = (cpu and string.match(cpu, "%d+%.?%d*")) or "0"

		load_avg = luci.sys.exec("awk '{print $2; exit}' /proc/loadavg 2>/dev/null"):gsub("\n", "") or "0"
		if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
			load_avg = "0"
		end
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		cpu = cpu,
		load_avg = tostring(math.floor(tonumber(load_avg) / tonumber(cpu_count) * 100));
	})
end

function action_toolbar_show()
	local pid = luci.sys.exec("pgrep -f '^[^ ]*mihomo' | head -1 | tr -d '\n' 2>/dev/null")
	if not pid or pid == "" then
		pid = luci.sys.exec("pgrep -f '^[^ ]*clash' | head -1 | tr -d '\n' 2>/dev/null")
	end
	if not pid or pid == "" then
		return
	end

	local _daip = daip()
	local _dase = dase() or ""
	local _cn_port = cn_port()
	if not _daip or not _cn_port then return end

	local traffic = json.parse(luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/traffic', _dase, _daip, _cn_port)))
	local connections = json.parse(luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Content-Type: application/json" -H "Authorization: Bearer %s" -XGET http://"%s":"%s"/connections', _dase, _daip, _cn_port)))

	local up, down, up_total, down_total, connection
	if traffic and connections and connections.connections then
		connection = #(connections.connections)
		up = rate(traffic.up)
		down = rate(traffic.down)
		up_total = fs.filesize(connections.uploadTotal)
		down_total = fs.filesize(connections.downloadTotal)
	else
		up, down = "0 B/S", "0 B/S"
		up_total, down_total = "0 KB", "0 KB"
		connection = "0"
	end

	local mem = tonumber(luci.sys.exec(string.format("cat /proc/%s/status 2>/dev/null |grep -w VmRSS |awk '{print $2}'", pid)))
	local cpu = luci.sys.exec(string.format([[
	top -b -n1 | awk -v pid="%s" '
		BEGIN { cpu_col=0; }
		$0 ~ /%%CPU/ {
			for(i=1;i<=NF;i++) if($i=="%%CPU") cpu_col=i;
			next
		}
		cpu_col>0 && $1==pid { print $cpu_col }
	'
	]], pid))

	mem = mem and fs.filesize(mem * 1024) or "0 KB"
	cpu = (cpu and string.match(cpu, "%d+%.?%d*")) or "0"

	local load_avg = luci.sys.exec("awk '{print $2; exit}' /proc/loadavg 2>/dev/null"):gsub("\n", "") or "0"
	local cpu_count = luci.sys.exec("grep -c ^processor /proc/cpuinfo 2>/dev/null"):gsub("\n", "") or 1
	if not string.match(load_avg, "^[0-9]*%.?[0-9]*$") then
		load_avg = "0"
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json({
		connections = connection,
		up = up,
		down = down,
		up_total = up_total,
		down_total = down_total,
		mem = mem,
		cpu = cpu,
		load_avg = tostring(math.floor(tonumber(load_avg) / tonumber(cpu_count) * 100));
	})
end

-- Lists /etc/clashnivo/config/*.yaml so the bottom-of-page toolbar can offer
-- a subscription switcher. Epic 2 populates the directory; until then this
-- returns an empty list and the toolbar JS hides itself.
local function config_name()
	local e, a = {}, nil
	for t, o in ipairs(fs.glob("/etc/clashnivo/config/*")) do
		a = require("nixio.fs").stat(o)
		if a then
			e[t] = {}
			e[t].name = fs.basename(o)
		end
	end
	return e
end

local function config_path()
	local cp = fs.uci_get_config("config", "config_path")
	return cp or ""
end

-- Returns just the basename of the active config file so the toolbar
-- dropdown (which lists basenames) can select the current entry.
local function active_config_name()
	local cp = config_path()
	if cp == "" then return "" end
	return fs.basename(cp)
end

function action_config_name()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		config_name = config_name(),
		config_path = active_config_name();
	})
end

function action_switch_config()
	local config_file = luci.http.formvalue("config_file")
	local config_nm = luci.http.formvalue("config_name")

	if not config_file and config_nm then
		config_file = "/etc/clashnivo/config/" .. config_nm
	end

	luci.http.prepare_content("application/json")
	if not config_file or not fs.access(config_file) then
		luci.http.write_json({
			status = "error",
			message = "Config file not found"
		})
		return
	end

	uci:set("clashnivo", "config", "config_path", config_file)
	uci:set("clashnivo", "config", "enable", "1")
	uci:commit("clashnivo")
	luci.sys.call("/etc/init.d/clashnivo restart >/dev/null 2>&1 &")

	luci.http.write_json({
		status = "success",
		config_file = config_file
	})
end

function action_close_all_connection()
	local _daip = daip()
	local _dase = dase() or ""
	local _cn_port = cn_port()
	if is_running() and _daip and _cn_port then
		luci.sys.exec(string.format('curl -sL -m 3 --retry 2 -H "Authorization: Bearer %s" -XDELETE http://"%s":"%s"/connections >/dev/null 2>&1', _dase, _daip, _cn_port))
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({ status = "ok" })
end

function action_reload_firewall()
	luci.sys.call("/etc/init.d/clashnivo reload >/dev/null 2>&1 &")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ status = "ok" })
end

function action_refresh_log()
	luci.http.prepare_content("application/json")
	local logfile = "/tmp/clashnivo.log"
	local log_len = tonumber(luci.http.formvalue("log_len")) or 0
	local core_refresh = luci.http.formvalue("core_refresh") == "true"

	if not fs.access(logfile) then
		luci.http.write_json({ len = 0, update = false, core_log = "", oc_log = "" })
		return
	end

	local total_lines = tonumber(luci.sys.exec("wc -l < " .. logfile)) or 0
	if total_lines == log_len and log_len > 0 then
		luci.http.write_json({ len = total_lines, update = false, core_log = "", oc_log = "" })
		return
	end

	local exclude_pattern = "UDP%-Receive%-Buffer%-Size|^Sec%-Fetch%-Mode|^User%-Agent|^Access%-Control|^Accept|^Origin|^Referer|^Connection|^Pragma|^Cache%-"
	local core_pattern = "level=|^time="
	local limit = 1000
	local start_line = (log_len > 0 and total_lines > log_len) and (log_len + 1) or 1

	local core_cmd = string.format(
		"tail -n +%d '%s' | grep -v -E '%s' | grep -E '%s' | tail -n %d",
		start_line, logfile, exclude_pattern, core_pattern, limit
	)
	local app_cmd = string.format(
		"tail -n +%d '%s' | grep -v -E '%s' | grep -v -E '%s' | tail -n %d",
		start_line, logfile, exclude_pattern, core_pattern, limit
	)

	local core_logs, app_logs = {}, {}

	if core_refresh then
		local core_raw = luci.sys.exec(core_cmd)
		if core_raw and core_raw ~= "" then
			for line in core_raw:gmatch("[^\n]+") do
				table.insert(core_logs, line)
			end
		end
	end

	local app_raw = luci.sys.exec(app_cmd)
	if app_raw and app_raw ~= "" then
		for line in app_raw:gmatch("[^\n]+") do
			if not string.match(string.sub(line, 1, 19), "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d") then
				line = os.date("%Y-%m-%d %H:%M:%S") .. ' [Fatal] ' .. line
			end
			table.insert(app_logs, trans_line(line))
		end
	end

	luci.http.write_json({
		len = total_lines,
		update = true,
		core_log = #core_logs > 0 and table.concat(core_logs, "\n") or "",
		oc_log = #app_logs > 0 and table.concat(app_logs, "\n") or ""
	})
end

function action_del_log()
	luci.sys.exec(": > /tmp/clashnivo.log")
end

function action_del_start_log()
	luci.sys.exec("echo '##FINISH##' > /tmp/clashnivo_start.log")
end

-- ---------------------------------------------------------------------------
-- Epic 2: subscription management
--
-- Scope cuts vs OpenClash:
--   * No set_subinfo_url / subscribe_info override section — UCI schema keeps
--     one subscription URL per entry; users edit the address in place. The
--     `subscribe_info` section type is not declared in uci-schema.md.
--   * No multi-provider YAML parsing in get_sub_url — single URL per entry.
--   * No #name= parsing for sub-info URLs — subscription.address is a single
--     or newline-joined URL list, but the first line is used for info.
--   * Only HTTP header `subscription-userinfo` is parsed. No body parsing.
-- ---------------------------------------------------------------------------

local function is_safe_subname(name)
	if not name or name == "" then return false end
	-- alphanumerics, dash, underscore; no path separators or dot-dot.
	return string.match(name, "^[%w][%w._%-]*$") ~= nil
end

-- Fetch subscription-userinfo header via curl HEAD-of-GET. Returns table
-- {http_code, surplus, used, total, percent, day_left, expire} or nil.
local function fetch_sub_info(sub_url, sub_ua)
	local info = luci.sys.exec(string.format(
		"curl -sLI -X GET -m 5 --retry 2 -w 'http_code=%%{http_code}' -H 'User-Agent: %s' '%s'",
		sub_ua or "clash.meta", sub_url))
	local http_code = string.match(info or "", "http_code=(%d+)")
	if not info or tonumber(http_code or "0") ~= 200 then
		info = luci.sys.exec(string.format(
			"curl -sLI -X GET -m 5 --retry 2 -w 'http_code=%%{http_code}' -H 'User-Agent: Quantumultx' '%s'",
			sub_url))
		http_code = string.match(info or "", "http_code=(%d+)")
	end
	if not info or tonumber(http_code or "0") ~= 200 then return nil end

	info = string.lower(info)
	if not string.find(info, "subscription%-userinfo") then return nil end

	local sub_line = ""
	for line in info:gmatch("[^\r\n]+") do
		if string.find(line, "subscription%-userinfo") then
			sub_line = line
			break
		end
	end

	local upload   = tonumber(string.match(sub_line, "upload=(%d+)"))
	local download = tonumber(string.match(sub_line, "download=(%d+)"))
	local total    = tonumber(string.match(sub_line, "total=(%d+)"))
	local expire_t = tonumber(string.match(sub_line, "expire=(%d+)"))

	local used      = (upload or 0) + (download or 0)
	local expire, day_left
	if expire_t == 0 or expire_t == nil then
		expire = (expire_t == 0) and "Long-term" or "null"
		day_left = (expire_t == 0) and "∞" or "null"
	else
		expire = os.date("%Y-%m-%d %H:%M:%S", expire_t)
		if os.time() <= expire_t then
			day_left = math.ceil((expire_t - os.time()) / 86400)
		else
			day_left = 0
		end
	end

	local percent, surplus
	if total and total > 0 and used <= total then
		percent = string.format("%.1f", ((total - used) / total) * 100)
		surplus = fs.filesize(total - used)
	elseif total and total > 0 then
		percent = "0"
		surplus = "-" .. fs.filesize(used - total)
	else
		percent = "0"
		surplus = "null"
	end

	return {
		http_code = http_code,
		surplus   = surplus,
		used      = fs.filesize(used),
		total     = (total and total > 0) and fs.filesize(total) or "null",
		percent   = percent,
		day_left  = day_left,
		expire    = expire
	}
end

-- Resolves a subscription name to its download URL. The `address` option may
-- hold one URL or several joined by \n or |; only the first is used.
local function get_sub_url(filename)
	local url
	uci:foreach("clashnivo", "config_subscribe", function(s)
		if s.name == filename and s.address then
			for line in string.gmatch(s.address, "[^\n|]+") do
				line = line:match("^%s*(.-)%s*$")
				if line and line ~= "" and string.find(line, "^https?://") then
					url = line
					return false
				end
			end
		end
	end)
	return url
end

function action_sub_info_get()
	local filename = luci.http.formvalue("filename")
	luci.http.prepare_content("application/json")

	if not filename or not is_safe_subname(filename) then
		luci.http.status(400, "Bad filename")
		return
	end

	-- Avoid slamming the upstream while the service is actively downloading.
	if is_running() then
		luci.http.write_json({ providers = {}, get_time = os.time() })
		return
	end

	local sub_ua = "clash.meta"
	uci:foreach("clashnivo", "config_subscribe", function(s)
		if s.name == filename and s.sub_ua then sub_ua = s.sub_ua end
	end)

	local url = get_sub_url(filename)
	local providers = {}
	if url then
		local info = fetch_sub_info(url, sub_ua)
		if info then table.insert(providers, info) end
	end

	luci.http.write_json({
		providers = providers,
		get_time  = os.time(),
		url_result = url and { type = "single", url = url } or nil
	})
end

function action_get_subscribe_data()
	local filename = luci.http.formvalue("filename")
	if not filename then
		luci.http.status(400, "Bad Request")
		return
	end
	local data = {}
	uci:foreach("clashnivo", "config_subscribe", function(s)
		if s.name == filename then data = s end
	end)
	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

-- Kicks off a subscription download for a single `filename`. The heavy
-- lifting is in clashnivo.sh, which will download, filter, assemble, and
-- restart the service. Returns immediately — the UI polls the start log.
function action_update_config()
	local filename = luci.http.formvalue("filename")
	luci.http.prepare_content("application/json")
	if not filename or not is_safe_subname(filename) then
		luci.http.write_json({ status = "error", message = "Bad filename" })
		return
	end
	local rc = luci.sys.call(string.format(
		"/usr/share/clashnivo/clashnivo.sh '%s' >/dev/null 2>&1 &", filename))
	if rc == 0 then
		luci.http.write_json({ status = "success", filename = filename })
	else
		luci.http.write_json({ status = "error", message = "Failed to trigger update" })
	end
end

-- Adds a new subscription or updates an existing one (idempotent on name).
-- Form fields mirror the schema §2 keys. Returns JSON {status, message}.
function action_add_subscription()
	local name     = luci.http.formvalue("name")
	local address  = luci.http.formvalue("address")
	local sub_ua   = luci.http.formvalue("sub_ua") or "clash.meta"
	local keyword  = luci.http.formvalue("keyword") or ""
	local ex_kw    = luci.http.formvalue("ex_keyword") or ""
	local de_ex_kw = luci.http.formvalue("de_ex_keyword") or ""

	luci.http.prepare_content("application/json")

	if not name or not address or name == "" or address == "" then
		luci.http.write_json({ status = "error", message = "Missing name or address" })
		return
	end
	if not is_safe_subname(name) then
		luci.http.write_json({ status = "error", message = "Invalid name (alphanumerics, dash, underscore, dot only)" })
		return
	end

	-- Normalise line endings and trim; accept `|` as an alternative separator.
	address = address:gsub("\r\n?", "\n")
	if string.find(address, "|") and not string.find(address, "\n") then
		address = address:gsub("|", "\n")
	end
	address = address:match("^%s*(.-)%s*$")

	-- Every non-empty line must be an HTTP(S) URL.
	for raw in address:gmatch("[^\n]+") do
		local line = raw:match("^%s*(.-)%s*$")
		if line ~= "" and not string.find(line, "^https?://") then
			luci.http.write_json({ status = "error", message = "Only HTTP/HTTPS URLs are supported" })
			return
		end
	end

	local existing
	uci:foreach("clashnivo", "config_subscribe", function(s)
		if s.name == name then existing = s[".name"]; return false end
	end)

	local sid = existing or uci:add("clashnivo", "config_subscribe")
	if not sid then
		luci.http.write_json({ status = "error", message = "UCI section create failed" })
		return
	end

	uci:set("clashnivo", sid, "enabled", "1")
	uci:set("clashnivo", sid, "name", name)
	uci:set("clashnivo", sid, "address", address)
	uci:set("clashnivo", sid, "sub_ua", sub_ua)

	local function set_list_or_clear(key, raw)
		uci:delete("clashnivo", sid, key)
		if raw and raw ~= "" then
			local list = {}
			for line in raw:gmatch("[^\n]+") do
				local v = line:match("^%s*(.-)%s*$")
				if v and v ~= "" then table.insert(list, v) end
			end
			if #list > 0 then uci:set_list("clashnivo", sid, key, list) end
		end
	end
	set_list_or_clear("keyword", keyword)
	set_list_or_clear("ex_keyword", ex_kw)
	uci:set("clashnivo", sid, "de_ex_keyword", de_ex_kw)

	uci:commit("clashnivo")
	luci.http.write_json({
		status  = "success",
		message = existing and "Subscription updated" or "Subscription added",
		name    = name
	})
end
