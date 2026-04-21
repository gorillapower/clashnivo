--[[
CBI entry point for the Log page. The page body is a TextValue that just
mounts the log view; all polling and display live in view/clashnivo/log.htm.
The config-editor template from OpenClash is Epic 3d scope and not mounted.
]]--

local m = Map("clashnivo", translate("Clash Nivo Logs"))
local s = m:section(TypedSection, "clashnivo")
m.pageaction = false
s.anonymous = true
s.addremove = false

local log = s:option(TextValue, "clog")
log.readonly = true
log.pollcheck = true
log.template = "clashnivo/log"
log.description = ""
log.rows = 29

m:append(Template("clashnivo/toolbar_show"))

return m
