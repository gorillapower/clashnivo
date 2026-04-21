--[[
Edit a single `servers` UCI section.

Protocol selector drives conditional field visibility via :depends("type", ...).
Five protocols are supported (ss, vmess, vless, trojan, hysteria2); the form
covers every field declared in uci-schema.md §3 that yml_proxys_set.sh actually
reads.

A missing/invalid sid redirects back to the list.
]]--

local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local uci  = luci.model.uci.cursor()
local fs   = require "luci.clashnivo"

local sid = arg[1]
local m, s, o

m = Map("clashnivo", translate("Edit Server"))
m.pageaction = false
m.redirect = DISP.build_url("admin/services/clashnivo/custom-servers")

if not sid or uci:get("clashnivo", sid) ~= "servers" then
	HTTP.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "servers")
s.anonymous = true
s.addremove = false

-- Config-file scoping. Lists the yaml files so the user can restrict a node
-- to one subscription rather than injecting it into all of them.
o = s:option(ListValue, "config", translate("Applies To"))
o.description = translate("Which subscription config this proxy is injected into. Choose \"All\" to apply everywhere.")
o:value("all", translate("All configs"))
for _, path in ipairs(fs.glob("/etc/clashnivo/config/*")) do
	local base = fs.basename(path)
	if base then o:value(base, base) end
end
o.default = "all"

-- Protocol type
o = s:option(ListValue, "type", translate("Type"))
o:value("ss",        "Shadowsocks")
o:value("vmess",     "VMess")
o:value("vless",     "VLESS")
o:value("trojan",    "Trojan")
o:value("hysteria2", "Hysteria2")
o.rmempty = false

-- Common required fields
o = s:option(Value, "name", translate("Name"))
o.description = translate("Proxy name — must be unique within the generated config.")
o.rmempty = false
function o.validate(self, value)
	if not value or value == "" then return nil, translate("Name is required") end
	if string.find(value, '"') or string.find(value, "\n") then
		return nil, translate("Name must not contain quotes or newlines")
	end
	return value
end

o = s:option(Value, "server", translate("Server"))
o.datatype = "host"
o.rmempty = false

o = s:option(Value, "port", translate("Port"))
o.datatype = "port"
o.default = "443"
o.rmempty = false

-- ----------------------------------------------------------------------------
-- Shadowsocks
-- ----------------------------------------------------------------------------
o = s:option(ListValue, "cipher", translate("Cipher"))
o:depends("type", "ss")
for _, v in ipairs({
	"aes-128-gcm", "aes-192-gcm", "aes-256-gcm",
	"aes-128-cfb", "aes-192-cfb", "aes-256-cfb",
	"aes-128-ctr", "aes-192-ctr", "aes-256-ctr",
	"chacha20-ietf", "chacha20-ietf-poly1305", "xchacha20-ietf-poly1305",
	"2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm",
	"2022-blake3-chacha20-poly1305",
	"rc4-md5", "none",
}) do o:value(v) end
o.default = "aes-256-gcm"

o = s:option(Value, "password", translate("Password"))
o:depends("type", "ss")
o:depends("type", "trojan")
o:depends("type", "hysteria2")
o.password = true

o = s:option(ListValue, "obfs", translate("Obfuscation"))
o:depends("type", "ss")
o:value("none", translate("None"))
o:value("http")
o:value("tls")
o:value("websocket")
o:value("shadow-tls")
o:value("restls")
o.default = "none"
o.rmempty = true

o = s:option(Value, "host", translate("Obfs Host"))
o:depends({ type = "ss", obfs = "http" })
o:depends({ type = "ss", obfs = "tls" })
o:depends({ type = "ss", obfs = "websocket" })
o.rmempty = true

o = s:option(Value, "obfs_password", translate("Obfs Password"))
o:depends({ type = "ss", obfs = "shadow-tls" })
o:depends({ type = "ss", obfs = "restls" })
o.password = true
o.rmempty = true

o = s:option(Value, "path", translate("v2ray-plugin Path"))
o:depends({ type = "ss", obfs = "websocket" })
o.rmempty = true

o = s:option(Flag, "udp_over_tcp", translate("UDP over TCP"))
o:depends("type", "ss")
o.rmempty = true

-- ----------------------------------------------------------------------------
-- VMess
-- ----------------------------------------------------------------------------
o = s:option(Value, "uuid", translate("UUID"))
o:depends("type", "vmess")
o:depends("type", "vless")

o = s:option(Value, "alterId", translate("AlterID"))
o:depends("type", "vmess")
o.datatype = "uinteger"
o.default = "0"

o = s:option(ListValue, "securitys", translate("Cipher"))
o:depends("type", "vmess")
o:value("auto")
o:value("aes-128-gcm")
o:value("chacha20-poly1305")
o:value("none")
o.default = "auto"

o = s:option(Flag, "xudp", translate("XUDP"))
o:depends("type", "vmess")
o:depends("type", "vless")
o.rmempty = true

o = s:option(ListValue, "packet_encoding", translate("Packet Encoding"))
o:depends("type", "vmess")
o:depends("type", "vless")
o:value("", translate("Default"))
o:value("packet")
o:value("xudp")
o:value("none")
o.rmempty = true

o = s:option(ListValue, "obfs_vmess", translate("Transport"))
o:depends("type", "vmess")
o:value("none", "TCP")
o:value("websocket", "WebSocket")
o:value("http", "HTTP")
o:value("h2", "HTTP/2")
o:value("grpc", "gRPC")
o.default = "none"

o = s:option(Value, "ws_opts_path", translate("WebSocket Path"))
o:depends({ type = "vmess", obfs_vmess = "websocket" })
o:depends({ type = "vless", obfs_vless = "ws" })
o.rmempty = true

o = s:option(DynamicList, "ws_opts_headers", translate("WebSocket Headers"))
o:depends({ type = "vmess", obfs_vmess = "websocket" })
o:depends({ type = "vless", obfs_vless = "ws" })
o.description = translate("One per line, format: Host: example.com")
o.rmempty = true

o = s:option(Value, "grpc_service_name", translate("gRPC Service Name"))
o:depends({ type = "vmess", obfs_vmess = "grpc" })
o:depends({ type = "vless", obfs_vless = "grpc" })
o:depends({ type = "trojan", obfs_trojan = "grpc" })
o.rmempty = true

-- ----------------------------------------------------------------------------
-- VLESS
-- ----------------------------------------------------------------------------
o = s:option(ListValue, "obfs_vless", translate("Transport"))
o:depends("type", "vless")
o:value("tcp", "TCP")
o:value("ws", "WebSocket")
o:value("grpc", "gRPC")
o:value("xhttp", "XHTTP")
o.default = "tcp"

o = s:option(ListValue, "vless_flow", translate("Flow"))
o:depends({ type = "vless", obfs_vless = "tcp" })
o:value("", translate("None"))
o:value("xtls-rprx-vision")
o.rmempty = true

o = s:option(Value, "vless_encryption", translate("Encryption"))
o:depends("type", "vless")
o.default = "none"
o.rmempty = true

o = s:option(Value, "reality_public_key", translate("REALITY Public Key"))
o:depends("type", "vless")
o.rmempty = true

o = s:option(Value, "reality_short_id", translate("REALITY Short ID"))
o:depends("type", "vless")
o.rmempty = true

o = s:option(Value, "xhttp_opts_path", translate("XHTTP Path"))
o:depends({ type = "vless", obfs_vless = "xhttp" })
o.rmempty = true

o = s:option(Value, "xhttp_opts_host", translate("XHTTP Host"))
o:depends({ type = "vless", obfs_vless = "xhttp" })
o.rmempty = true

-- ----------------------------------------------------------------------------
-- Trojan
-- ----------------------------------------------------------------------------
o = s:option(ListValue, "obfs_trojan", translate("Transport"))
o:depends("type", "trojan")
o:value("none", "TCP")
o:value("ws", "WebSocket")
o:value("grpc", "gRPC")
o.default = "none"

o = s:option(Value, "trojan_ws_path", translate("WebSocket Path"))
o:depends({ type = "trojan", obfs_trojan = "ws" })
o.rmempty = true

o = s:option(DynamicList, "trojan_ws_headers", translate("WebSocket Headers"))
o:depends({ type = "trojan", obfs_trojan = "ws" })
o.description = translate("One per line, format: Host: example.com")
o.rmempty = true

-- ----------------------------------------------------------------------------
-- Hysteria2
-- ----------------------------------------------------------------------------
o = s:option(Value, "hysteria_up", translate("Upload Bandwidth"))
o:depends("type", "hysteria2")
o.placeholder = "50 Mbps"
o.rmempty = true

o = s:option(Value, "hysteria_down", translate("Download Bandwidth"))
o:depends("type", "hysteria2")
o.placeholder = "200 Mbps"
o.rmempty = true

o = s:option(DynamicList, "hysteria_alpn", translate("ALPN"))
o:depends("type", "hysteria2")
o:value("h3")
o:value("h2")
o:value("http/1.1")
o.rmempty = true

o = s:option(ListValue, "hysteria_obfs", translate("Obfuscation"))
o:depends("type", "hysteria2")
o:value("", translate("None"))
o:value("salamander")
o.rmempty = true

o = s:option(Value, "hysteria_obfs_password", translate("Obfs Password"))
o:depends({ type = "hysteria2", hysteria_obfs = "salamander" })
o.password = true
o.rmempty = true

o = s:option(Value, "ports", translate("Port Hopping Range"))
o:depends("type", "hysteria2")
o.description = translate("e.g. 20000-40000. Leave blank to use a fixed port.")
o.rmempty = true

o = s:option(ListValue, "hysteria2_protocol", translate("Protocol"))
o:depends("type", "hysteria2")
o:value("", translate("Default (UDP)"))
o:value("udp")
o:value("faketcp")
o.rmempty = true

o = s:option(Value, "hop_interval", translate("Hop Interval (seconds)"))
o:depends("type", "hysteria2")
o.datatype = "uinteger"
o.rmempty = true

-- ----------------------------------------------------------------------------
-- Shared transport / TLS knobs (apply to all protocols)
-- ----------------------------------------------------------------------------
o = s:option(Flag, "udp", translate("Enable UDP"))
o.rmempty = true

o = s:option(Flag, "tls", translate("TLS"))
o:depends("type", "vmess")
o:depends("type", "vless")
o:depends("type", "trojan")
o.rmempty = true

o = s:option(Flag, "skip_cert_verify", translate("Skip TLS Cert Verify"))
o.rmempty = true

o = s:option(Value, "sni", translate("SNI"))
o.rmempty = true

o = s:option(Value, "servername", translate("Server Name"))
o:depends("type", "vmess")
o:depends("type", "vless")
o.description = translate("Alias of SNI used by some protocols.")
o.rmempty = true

o = s:option(DynamicList, "alpn", translate("ALPN"))
o:depends("type", "trojan")
o:value("h2")
o:value("http/1.1")
o:value("h3")
o.rmempty = true

o = s:option(Value, "fingerprint", translate("Server Fingerprint"))
o.rmempty = true

o = s:option(ListValue, "client_fingerprint", translate("Client uTLS Fingerprint"))
o:value("", translate("None"))
for _, v in ipairs({"chrome","firefox","safari","ios","android","edge","360","qq","random"}) do
	o:value(v)
end
o.rmempty = true

o = s:option(ListValue, "ip_version", translate("IP Version"))
o:value("", translate("Default"))
o:value("dual")
o:value("ipv4")
o:value("ipv6")
o:value("ipv4-prefer")
o:value("ipv6-prefer")
o.rmempty = true

o = s:option(Flag, "tfo", translate("TCP Fast Open"))
o.rmempty = true

o = s:option(Value, "interface_name", translate("Bind Interface"))
o.rmempty = true

o = s:option(Value, "routing_mark", translate("Routing Mark"))
o.datatype = "string"
o.rmempty = true

o = s:option(Value, "dialer_proxy", translate("Dial Through Proxy"))
o.description = translate("Chain this node through another named proxy.")
o.rmempty = true

-- Multiplex (smux) — simple enable + protocol is enough for v1.
o = s:option(Flag, "multiplex", translate("Enable SMUX"))
o.rmempty = true

o = s:option(ListValue, "multiplex_protocol", translate("SMUX Protocol"))
o:depends("multiplex", "1")
o:value("", translate("Default"))
o:value("smux")
o:value("yamux")
o:value("h2mux")
o.rmempty = true

o = s:option(TextValue, "other_parameters", translate("Extra YAML"))
o.description = translate("Raw YAML fragment appended to this proxy entry (advanced).")
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
