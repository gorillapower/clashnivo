--[[
CBI entry point for the Overview page. Mounts the status widget and the
bottom toolbar. No form fields live here — the whole page is driven by
AJAX polling from view/clashnivo/status.htm.

The Mihomo core manager lives on the System page (see ui-nav.md §Overview
vs §System). Overview's only core-related element is the version indicator
inside the status widget.
]]--

local m = SimpleForm("clashnivo", translate("Clash Nivo"))
m.description = translate("A Mihomo proxy manager for OpenWrt.")
m.reset = false
m.submit = false

m:section(SimpleSection).template = "clashnivo/status"

m:append(Template("clashnivo/toolbar_show"))

return m
