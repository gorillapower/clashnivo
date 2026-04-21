# Execution Plan

## Product Assumptions

- Target user: English-speaking, non-expert, wants a working transparent proxy
  without reading Clash documentation.
- OpenWrt target: fw4 (nftables) primary, fw3 (iptables) secondary.
- Mihomo (Clash Meta) is the only supported core binary.
- Stack: LuCI CBI (Lua), plain JavaScript for dynamic behaviour, shell + Ruby for
  backend. No build step. No Node.js runtime.
- The app installs and runs independently alongside OpenClash with no conflicts.

## Execution Model

1. Settle or refresh relevant decision docs.
2. Settle or refresh relevant architecture docs.
3. Create or refresh the near-term issue batch.
4. Execute one task at a time.
5. Verify explicitly (test on-device or via config validation).
6. Commit and publish.
7. Reassess after a small batch or boundary change.

---

## Pre-Build Audit (required before Epic 0)

Before any code is written, complete a verified audit of the OpenClash source
against our planned scope. The audit has two outputs:

1. **Script inventory** — for every script in our `repo-layout.md`, confirm
   what the OpenClash original actually does, decide copy/fork/cut, and note
   exactly what changes a fork needs. Cover at minimum: `openclash.sh`,
   `init.d/openclash`, `yml_proxys_set.sh`, `yml_groups_set.sh`,
   `yml_rules_change.sh`, `openclash_core.sh`, `ruby.sh`, `uci.sh`.

2. **UCI schema** — define every field in `/etc/config/clashnivo`: section
   type, option name, type (boolean/string/list), default value, which
   pipeline stage reads it. This becomes the reference for all script forks
   and the CBI settings page.

The audit is done when both outputs exist as docs and have been reviewed.
Do not start Epic 0 until this gate is passed.

---

## Epic Order

### Epic 0 — Scaffold

**Goal:** A working package that installs, starts, stops, and produces a valid
`config.yaml`. No UI features beyond start/stop. Proves the copy-rename approach
works end to end.

**Outputs:**
- Makefile with correct package metadata
- `/etc/init.d/clashnivo` — forked, renamed, starts Mihomo binary
- `/etc/config/clashnivo` — UCI defaults (ports, mode, DNS placeholder)
- `uci.sh`, `log.sh`, `ruby.sh`, `YAML.rb` — direct copies
- `clashnivo.sh` — forked, subscription download + config assembly entry point
- `yml_proxys_set.sh` — forked and renamed
- `yml_groups_set.sh` — forked, renamed, include-all-proxies behaviour
- `yml_rules_change.sh` — forked, renamed, chnroute/streaming stripped
- `clashnivo_core.sh` — forked, binary download
- `clashnivo_watchdog.sh` — forked
- All supporting scripts copied and renamed
- One valid subscription download + assembly that produces a startable config

---

### Epic 1 — Core UI shell

**Goal:** A navigable LuCI app with a working overview page, log viewer, and the
ability to start/stop the service from the UI. No custom features yet.

**Outputs:**
- `clashnivo.lua` controller — nav structure, AJAX status endpoints
- `overview.lua` CBI — status panel, start/stop, mode display, API link
- `status.htm` view — AJAX-polled running/stopped widget
- `log.lua` + `log.htm` — log tail viewer
- `toolbar_show.htm` — bottom toolbar
- `settings.lua` CBI — tabbed settings (op mode, ports, DNS redirect mode)
- rpcd ACL, ucitrack, uci-defaults all wired up

---

### Epic 2 — Subscription management

**Goal:** Users can add subscriptions, trigger downloads, configure auto-update,
and switch the active config.

**Outputs:**
- `subscription.lua` + `subscription-edit.lua` CBI — add/edit/delete subscriptions
- Auto-update cron wiring in init.d
- Manual refresh endpoint in controller
- Sub info display (expiry, traffic remaining) from subscription headers
- `config.lua` CBI — list config files, switch active, upload manual YAML
- Keyword node filter fields on subscription edit form

---

### Epic 3 — Custom features

**Goal:** All four customisation features working end to end. This is the core
value proposition of the app.

#### Epic 3a — Custom servers

- `custom-servers.lua` + `custom-servers-edit.lua` CBI
- Protocol support: SS, VMess, VLess, Trojan, Hysteria2
- URL import (paste a `ss://` / `vmess://` / etc. URI, parsed into form fields)
- `yml_proxys_set.sh` generates correct YAML for each protocol

#### Epic 3b — Custom groups

- `custom-groups.lua` + `custom-groups-edit.lua` CBI
- Group types: select, url-test, fallback, load-balance
- Fields: name, type, filter regex, exclude-filter regex, test URL, interval, strategy
- All groups get `include-all-proxies: true` in generated YAML

#### Epic 3c — Custom rules & rule providers

- `custom-rules.lua` CBI — one page with two stacked sections:
  1. Rule-provider list (`rule_provider` UCI type; add/edit/delete entries;
     upload local files or register remote URLs; pick behavior/format)
  2. Custom rule list (individual Clash rules; may reference a provider
     via `RULE-SET,<name>,<target>`)
- Rules prepended to the subscription rule list at assembly time; providers
  emitted into the `rule-providers:` block alongside
- Local rule-set files live at `/etc/clashnivo/rule_provider/<name>.<ext>`
- `yml_rule_provider_set.sh` (fork of OpenClash's equivalent) writes the
  `rule-providers:` block; `yml_rules_change.sh` handles rule prepend
- Basic validation: rule format check and provider-name reference check

#### Epic 3d — Config overwrite

- `config-overwrite.lua` CBI — YAML editor with syntax highlighting (CodeMirror)
- Preview: show a diff of what the overwrite changes
- Optional remote URL source with auto-update schedule
- Multiple overwrite sources applied in order

---

### Epic 4 — Binary management

**Goal:** Users can install and update the Mihomo core from within the UI.

**Outputs:**
- Core install/update button on the overview page
- Version display (installed vs. latest)
- `clashnivo_core.sh` correctly downloads for the router's architecture
- `clashnivo_version.sh` checks upstream release

---

### Epic 5 — Polish and hardening

**Goal:** The app is production-quality — every label has a description, every
error is visible, the UI is tested on multiple OpenWrt versions.

**Outputs:**
- All form fields have `description` text
- Error states surface clearly (missing core, bad config, DNS revert failure)
- LAN access control (black/whitelist by IP/MAC) exposed in settings
- BT/PT DIRECT rules toggle in settings
- GEO data auto-update configuration
- Flush DNS cache button
- Auto-restart schedule setting
- End-to-end testing on OpenWrt 23.05 (fw4) and 21.02 (fw3)

---

## Current Batch

1. Pre-build audit — script inventory (openclash.sh, init.d, yml_*.sh, core, helpers)
2. Pre-build audit — UCI schema definition
3. Epic 0 — begin scaffold: fork init.d, copy helper scripts, rename throughout
4. Epic 0 — UCI defaults and Makefile
5. Epic 0 — validate one subscription download produces a startable config

---

## Ticket Authoring Rules

- One bounded behaviour or module slice per task.
- Name exact files in scope and out of scope.
- Include concrete acceptance criteria.
- Include verification steps (how to confirm it works on-device or via config validation).
- Link relevant decision and architecture docs.
