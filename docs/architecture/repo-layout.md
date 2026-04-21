# Repo Layout

Status: Settled

## Purpose

Define the intended internal structure of the `luci-app-clashnivo` package so
that all implementation work lands in one agreed shape.

---

## Layout Rule

The repo mirrors the standard OpenWrt LuCI package layout. Source is organised
by layer: Lua controller/models, HTML view templates, shell/Ruby backend scripts,
and static frontend assets. Each layer is separate; no cross-layer direct calls
except through the documented service contract.

---

## Target Layout

```
luci-app-clashnivo/
│
├── Makefile                               # OpenWrt package definition
│
├── luasrc/
│   ├── controller/
│   │   └── clashnivo.lua                  # All LuCI routes: nav entries + AJAX
│   │                                      # endpoints called by the UI
│   │
│   ├── model/cbi/clashnivo/
│   │   ├── overview.lua                   # Status overview + start/stop controls
│   │   ├── settings.lua                   # Core settings (mode, ports, DNS) — tabbed
│   │   ├── subscription.lua               # Subscription list + auto-update schedule
│   │   ├── subscription-edit.lua          # Edit a single subscription entry
│   │   ├── custom-servers.lua             # Custom proxy server list
│   │   ├── custom-servers-edit.lua        # Edit a single custom server
│   │   ├── custom-groups.lua              # Custom proxy group list
│   │   ├── custom-groups-edit.lua         # Edit a single custom group (name, type,
│   │   │                                  # filter regex, test URL, strategy)
│   │   ├── custom-rules.lua               # Custom rules list (prepended to sub rules)
│   │   ├── config-overwrite.lua           # YAML overwrite editor + overwrite sources
│   │   ├── config.lua                     # Config file manager (list, switch, upload)
│   │   └── log.lua                        # Log viewer (clashnivo.log)
│   │
│   ├── openclash.lua                      # Shared Lua file/fs helpers (renamed copy)
│   │
│   └── view/clashnivo/
│       ├── status.htm                     # Running status widget (AJAX-polled)
│       ├── log.htm                        # Log tail view
│       ├── toolbar_show.htm               # Bottom toolbar (start/stop/reload buttons)
│       ├── switch_mode.htm                # Inline mode switcher widget
│       ├── flush_dns_cache.htm            # Flush DNS button widget
│       ├── server_url.htm                 # URL import widget for servers
│       └── tblsection.htm                 # Sortable table section template
│
├── root/
│   ├── etc/
│   │   ├── config/
│   │   │   └── clashnivo                  # UCI config defaults
│   │   └── init.d/
│   │       └── clashnivo                  # procd init script (fork of openclash init.d)
│   │
│   └── usr/share/clashnivo/
│       ├── clashnivo.sh                   # Main startup + subscription download script
│       │                                  # (fork of openclash.sh, renamed throughout)
│       ├── yml_proxys_set.sh              # UCI servers → proxies: YAML block
│       │                                  # (fork of yml_proxys_set.sh)
│       ├── yml_groups_set.sh              # UCI groups → proxy-groups: YAML block
│       │                                  # (fork of yml_groups_set.sh, all groups get
│       │                                  # include-all-proxies: true + filter)
│       ├── yml_rules_change.sh            # Prepend custom rules to rules: list
│       │                                  # (fork of yml_rules_change.sh, simplified:
│       │                                  # no chnroute, no streaming unlock logic)
│       ├── clashnivo_core.sh              # Binary download + version management
│       │                                  # (fork of openclash_core.sh)
│       ├── clashnivo_version.sh           # Check latest upstream version
│       ├── clashnivo_watchdog.sh          # Process health monitor
│       │                                  # (fork of openclash_watchdog.sh)
│       ├── clashnivo_update.sh            # Self-update (luci-app-clashnivo package)
│       ├── log.sh                         # LOG_OUT / LOG_ERROR helpers (direct copy)
│       ├── ruby.sh                        # Ruby YAML helpers: ruby_cover, ruby_merge,
│       │                                  # etc. (direct copy)
│       ├── YAML.rb                        # Ruby YAML library extension (direct copy)
│       ├── uci.sh                         # uci_get_config() helper (copy, s/openclash/clashnivo/)
│       ├── clashnivo_ps.sh                # Process utilities (fork of openclash_ps.sh)
│       ├── clashnivo_curl.sh              # Curl download helpers (fork)
│       ├── clashnivo_get_network.lua      # WAN interface/DNS detection (fork)
│       │
│       ├── res/
│       │   └── default.yaml              # Default Mihomo config template
│       │
│       └── ui/
│           ├── metacubexd/               # MetaCubeXD dashboard (copy)
│           └── zashboard/                # Zashboard dashboard (copy)
│
├── root/www/luci-static/resources/clashnivo/
│   ├── lib/
│   │   └── codemirror.js                 # CodeMirror editor (copy)
│   ├── addon/                            # CodeMirror addons (copy)
│   │   ├── lint/                         # YAML lint
│   │   └── ...
│   ├── mode/yaml/yaml.js                 # YAML syntax mode (copy)
│   └── theme/material.css               # Editor theme (copy)
│
├── root/usr/share/rpcd/acl.d/
│   └── luci-app-clashnivo.json           # rpcd ACL (fork of openclash ACL)
│
├── root/usr/share/ucitrack/
│   └── luci-app-clashnivo.json           # ucitrack config (fork)
│
├── root/etc/uci-defaults/
│   └── luci-clashnivo                    # First-boot UCI defaults (fork)
│
├── po/
│   └── en/
│       └── clashnivo.po                  # English strings (new, not translated)
│
└── tools/
    └── po2lmo/                           # .po → .lmo compiler (direct copy)
```

---

## Naming Convention

Every file derived from OpenClash is either a **direct copy** (no logic change,
only string substitution) or a **fork** (logic changed). Comments in forks should
note what was removed or changed relative to the OpenClash original.

String substitution applied to all forks:
- `openclash` → `clashnivo` (UCI config name, paths, chain names, log prefix)
- `OpenClash` → `Clash Nivo` (UI labels)
- `CLASH` → `CLASHNIVO` (iptables/nftables chain prefix)
- `/etc/openclash/` → `/etc/clashnivo/`
- `/usr/share/openclash/` → `/usr/share/clashnivo/`

---

## Transitional Paths

- `yml_rules_change.sh` initially keeps the BT/PT DIRECT rule injection from
  OpenClash. Streaming unlock, chnroute, and developer-mode logic is removed at
  fork time.
- The `clashnivo_core.sh` fork may initially support only the Mihomo Meta core
  (not alpha/beta branches). Branch selection can be added later.

---

## Legacy Debt

- None at project start. Do not introduce OpenWrt-incompatible dependencies.
- Do not add Node.js, Python, or any runtime not already on OpenWrt base images.
  Lua, shell, and Ruby (already a dependency via OpenClash lineage) are acceptable.

---

## Change Control

- Later tasks should land files in the paths above.
- If a new file is needed that doesn't fit the layout, update this document first
  and state the reason.
