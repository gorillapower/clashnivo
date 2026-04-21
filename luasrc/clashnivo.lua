--[[
LuCI - Filesystem and UCI helpers for Clash Nivo

Forked from luci-app-openclash luasrc/openclash.lua. Module path renamed
luci.openclash -> luci.clashnivo. UCI namespace renamed openclash -> clashnivo.
uci_get_config() simplified: Clash Nivo has no @overwrite[0] override section
(the whole singleton lives in named section `config`), so there is no fallback
chain to walk. lanip() rewritten for the same reason.

Every CBI, controller, and view in luci-app-clashnivo loads this module.
]]--

local io    = require "io"
local os    = require "os"
local ltn12 = require "luci.ltn12"
local fs	= require "nixio.fs"
local nutil = require "nixio.util"
local uci = require "luci.model.uci".cursor()
local SYS  = require "luci.sys"
local HTTP = require "luci.http"

local type  = type
local string  = string

module "luci.clashnivo"

access = fs.access

function glob(...)
	local iter, code, msg = fs.glob(...)
	if iter then
		return nutil.consume(iter)
	else
		return nil, code, msg
	end
end

function isfile(filename)
	return fs.stat(filename, "type") == "reg"
end

function isdirectory(dirname)
	return fs.stat(dirname, "type") == "dir"
end

readfile = fs.readfile
writefile = fs.writefile
copy = fs.datacopy
rename = fs.move

function mtime(path)
	return fs.stat(path, "mtime")
end

function utime(path, mtime, atime)
	return fs.utimes(path, atime, mtime)
end

basename = fs.basename
dirname = fs.dirname

function dir(...)
	local iter, code, msg = fs.dir(...)
	if iter then
		local t = nutil.consume(iter)
		t[#t+1] = "."
		t[#t+1] = ".."
		return t
	else
		return nil, code, msg
	end
end

function mkdir(path, recursive)
	return recursive and fs.mkdirr(path) or fs.mkdir(path)
end

rmdir = fs.rmdir

local stat_tr = {
	reg = "regular",
	dir = "directory",
	lnk = "link",
	chr = "character device",
	blk = "block device",
	fifo = "fifo",
	sock = "socket"
}

function stat(path, key)
	local data, code, msg = fs.stat(path)
	if data then
		data.mode = data.modestr
		data.type = stat_tr[data.type] or "?"
	end
	return key and data and data[key] or data, code, msg
end

chmod = fs.chmod

function link(src, dest, sym)
	return sym and fs.symlink(src, dest) or fs.link(src, dest)
end

unlink = fs.unlink
readlink = fs.readlink

function filename(str)
	if not str then
		return nil
	end
	local idx = str:match(".+()%.%w+$")
	if idx then
		return str:sub(1, idx-1)
	else
		return str
	end
end

function filesize(e)
	local t=0
	local a={' KB',' MB',' GB',' TB',' PB'}
	if e < 0 then
        e = -e
    end
	repeat
		e=e/1024
		t=t+1
	until(e<=1024)
	return string.format("%.1f",e)..a[t] or "0.0 KB"
end

function lanip()
	local lan_int_name = uci:get("clashnivo", "config", "lan_interface_name") or "0"
	local lan_ip
	if lan_int_name == "0" then
		lan_ip = SYS.exec("uci -q get network.lan.ipaddr 2>/dev/null |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
	else
		lan_ip = SYS.exec(string.format("ip address show %s 2>/dev/null | grep -w 'inet' 2>/dev/null | grep -Eo 'inet [0-9\\.]+' | awk '{print $2}' | head -1 | tr -d '\n'", lan_int_name))
	end
	if not lan_ip or lan_ip == "" then
		lan_ip = SYS.exec("ip address show $(uci -q -p /tmp/state get network.lan.ifname || uci -q -p /tmp/state get network.lan.device) | grep -w 'inet'  2>/dev/null | grep -Eo 'inet [0-9\\.]+' | awk '{print $2}' | head -1 | tr -d '\n'")
	end
	if not lan_ip or lan_ip == "" then
		lan_ip = SYS.exec("ip addr show 2>/dev/null | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\\.]+' | awk '{print $2}' | head -n 1 | tr -d '\n'")
	end
	return lan_ip
end

function find_case_insensitive_path(path)
    local dir = dirname(path)
    local base = basename(path)
    local files = dir and fs.dir(dir)
    if not files then
        return nil
    end

    for f in files do
        if f:lower() == base:lower() then
            return dir .. "/" .. f
        end
    end
    return nil
end

function get_resourse_mtime(path)
    local real_path = path
    if not fs.access(path) then
        local found = find_case_insensitive_path(path)
        if found then
            real_path = found
        else
            return "File Not Exist"
        end
    end
    local file = fs.readlink(real_path) or real_path
	local resourse_etag_version = SYS.exec(string.format("source /usr/share/clashnivo/clashnivo_etag.sh && GET_ETAG_TIMESTAMP_BY_PATH '%s'", real_path))
    if resourse_etag_version and resourse_etag_version ~= "" then
		return resourse_etag_version
	end
	local resourse_version = os.date("%Y-%m-%d %H:%M:%S", mtime(real_path))
	if resourse_version and resourse_version ~= "" then
        return resourse_version
	end
    return "Unknown"
end

function uci_get_config(section, key)
    return uci:get("clashnivo", section, key)
end

function get_file_path_from_request()
	local file_path
	local referer = HTTP.getenv("HTTP_REFERER")
	if referer then
		local _, _, file_value = referer:find("file=([^&]*)$")
		if file_value and file_value ~= "" then
			file_path = HTTP.urldecode(file_value)
		end
	end

	if not file_path or file_path == "/" then
		file_path = HTTP.formvalue("file")
		if not file_path then
			file_path = HTTP.urldecode(file_path)
		end
	end

	return file_path
end
