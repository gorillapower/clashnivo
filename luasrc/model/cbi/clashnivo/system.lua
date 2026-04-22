--[[
System page. Per docs/architecture/ui-nav.md §System this entry collects
binary management, asset maintenance, scheduled tasks, and startup config.

Only the Mihomo core manager ships in Epic 4. GEO refresh, package update,
auto-restart scheduling, and startup config (delay_start, small_flash_memory)
land in Epic 5 and will be added as additional stacked sections here.
]]--

local m = SimpleForm("clashnivo", translate("System"))
m.description = translate("System-level maintenance: core binary, assets, scheduled tasks, and startup config. More controls arrive in Epic 5.")
m.reset = false
m.submit = false

m:section(SimpleSection).template = "clashnivo/core_manage"

m:append(Template("clashnivo/toolbar_show"))

return m
