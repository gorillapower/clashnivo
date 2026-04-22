--[[
Log page. Hosts the log viewer (tab per pane), log-level switcher, and the
Clear button. All polling and rendering lives in view/clashnivo/log.htm.

Structured as SimpleForm + SimpleSection so the template renders full-width.
An earlier TextValue-wrapped version collapsed the template inside a
cbi-value flex row, shoving the tab buttons and log panes into narrow
columns (visible bug on 2026-04-22).
]]--

local m = SimpleForm("clashnivo", translate("Clash Nivo Logs"))
m.description = translate("Live log tail. Log level is set here — it takes effect on the running core via the controller API and is written to UCI for subsequent runs.")
m.reset = false
m.submit = false

m:section(SimpleSection).template = "clashnivo/log"

m:append(Template("clashnivo/toolbar_show"))

return m
