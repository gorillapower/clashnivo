--[[
CBI entry point for the Overview page. Mounts the status widget and the
bottom toolbar. No form fields live here — the whole page is driven by
AJAX polling from view/clashnivo/status.htm.
]]--

local m = SimpleForm("clashnivo", translate("Clash Nivo"))
m.description = translate("A Mihomo proxy manager for OpenWrt.")
m.reset = false
m.submit = false

m:section(SimpleSection).template = "clashnivo/status"

m:append(Template("clashnivo/toolbar_show"))

return m
