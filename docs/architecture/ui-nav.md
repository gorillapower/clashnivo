# UI Navigation Design

Status: Settled (pending review pass)

## Stack

LuCI CBI (Lua) — no build step, no Node.js. Plain JavaScript for dynamic
behaviour. This document defines information architecture only; it does not
prescribe implementation details.

---

## Nav Entries

Six top-level LuCI nav entries under `admin/services/clashnivo`:

| # | Entry | Purpose |
|---|---|---|
| 1 | Overview | Status, start/stop, mode switch, dashboard link, onboarding wizard |
| 2 | Subscriptions | Subscriptions, config files, subscription auto-update schedule |
| 3 | Customize | Custom servers, groups, rules, config overwrite |
| 4 | Settings | Tabbed: Clash / Router |
| 5 | Log | Log viewer, log size, log level |
| 6 | System | Core, GEO, package update, scheduled tasks, startup config |

---

## Page Detail

### Overview

- Running / stopped status indicator
- Start, Stop, Restart buttons
- Mode switcher (rule / global / direct)
- Active config name
- Core version + API reachable indicator
- Open Dashboard button (links to Mihomo REST UI)
- Setup onboarding flow: install core → add source → start service

---

### Subscriptions

- Subscription list — add, edit, delete, manual refresh per subscription
- Subscription info display — expiry, traffic quota (from subscription headers)
- Subscription auto-update schedule — enable, day of week, hour

  > Earmarked for review after implementation: confirm co-locating the
  > auto-update schedule here (rather than System) still makes sense once
  > the page exists.

- Config file list — list all YAMLs in `/etc/clashnivo/config/`, switch
  active, upload manual YAML, delete

---

### Customize

Four custom features — the core value proposition:

- **Custom servers** — list + edit form per server
  - Protocols: SS, VMess, VLess, Trojan, Hysteria2
  - URL import (paste `ss://` / `vmess://` / etc. URI)
- **Custom groups** — list + edit form per group
  - Types: select, url-test, fallback, load-balance
  - Fields: name, type, filter regex, exclude-filter regex, test URL,
    interval, strategy
  - All groups get `include-all-proxies: true` in generated YAML
- **Custom rules** — list of individual Clash rules prepended at assembly
- **Config overwrite** — YAML editor + overwrite sources (URL or inline)

---

### Settings

Two tabs. Grouping principle: **by responsibility** — what system each
setting configures.

#### Clash tab
*Settings that configure the Mihomo binary or its generated config.yaml.*

- Op mode (fake-ip / redir-host / TUN)
- UDP proxy
- TUN stack type (conditional on TUN mode)
- Controller port (Mihomo API, default 9090)
- API secret (dashboard password)
- Dashboard HTTP/HTTPS toggle
- Dashboard install / update (MetaCubeXD, Zashboard)
- DNS port (Mihomo DNS listener, default 7874)
- TProxy port (default 7895)
- IPv6 DNS fallback
- Append default DNS
- Append WAN DNS
- Custom DNS server + domain list
- Disable quic-go GSO (binary startup flag for Linux 6.6+)

#### Router tab
*Settings that configure OpenWrt firewall (iptables/nftables) and dnsmasq.*

- DNS redirect method (Dnsmasq / Firewall / Disabled)
- Flush DNS cache (button)
- China bypass mode (disable / bypass mainland / bypass overseas)
- Common ports only (toggle)
- Disable QUIC (block UDP 443)
- Router self-proxy
- Bypass gateway compatible
- Interface binding (LAN interface name)
- Device access mode (all / blacklist / whitelist) + IP/MAC lists
- WAN bypass hosts + WAN bypass ports
- Custom firewall rules (textarea → shell script)

---

### Log

- Log viewer — two tabs: Clash Nivo log / Clash Core log
- Controls: line count, pause/resume, clear
- Log size (KB)
- Log level

---

### System

Three concerns: binary management, asset maintenance, startup config.

**Clash Core**
- Installed version + latest version display
- Install / Update button
- Download source selector (auto / official / jsDelivr / custom URL)
- Check source latency button

**GEO Assets**
- Manual refresh button (all: GeoIP MMDB, GeoIP Dat, GeoSite, GeoASN)
- Auto-update schedule — enable, day of week, hour

**Package**
- Latest version display
- Check + Update luci-app-clashnivo package

**Scheduled tasks**
- Auto-restart — enable, day of week, hour

**Startup config**
- Delay start (seconds)
- Small flash memory (move core + GEO to /tmp)

---

## Design Goals

The target user is technically literate but not a networking expert. They
understand what a proxy does; they may not know the difference between
fake-ip and redir-host. The design serves them, not a beginner who has
never heard of DNS.

1. **Mirror the pipeline.** Nav structure reflects the assembly pipeline
   stages (see `system-pipeline.md`). Users who learn the system once can
   predict where things live. Subscriptions = Stage 1-2, Customize =
   Stage 3-6, Settings = Stage 7/9/10, System = everything outside the
   pipeline.

2. **No chrome, no fluff.** No status badges, icon soup, empty-state
   illustrations, or decorative callouts. Form fields, tables, buttons.
   Less cluttered and more coherent than OpenClash is the bar.

3. **Coherent over clever.** Fewer ways to do the same thing. One obvious
   place for each setting, not multiple entry points.

4. **Tooltips teach.** Every non-obvious setting has a tooltip that
   explains *what* it does and *when* it matters. If we can't write that
   tooltip, we don't understand the setting well enough to ship it —
   either learn it or drop it.

5. **UCI is the only source of truth.** UI holds no state that isn't in
   UCI. No localStorage preferences, no hidden server-side memory. What
   the user sees in the form = what's in `/etc/config/clashnivo` = what
   ends up in `config.yaml`.

6. **Actions look different from settings.** Buttons (install, refresh,
   restart) are visually distinct from form fields. System is mostly
   buttons; Settings is mostly fields. The difference in interaction mode
   is why they're separate nav entries.

7. **LuCI and the dashboard are complementary.** LuCI owns configuration
   (subscriptions, rules, settings, system maintenance). The external
   dashboard (MetaCubeXD / Zashboard) owns runtime (proxy selection per
   group, connection monitoring, latency tests). Overview links to the
   dashboard as a first-class action.

8. **Clean coexistence with OpenClash.** No label, path, port, iptables
   chain name, or default that collides. Both can run on the same router.

9. **First-run wizard only if it earns its keep.** Must perform real
   actions (install core → add subscription → start service) in 2–3
   steps. If it's just explanatory text, skip it.

---

## Design Principles

- **Responsibility-based grouping** in Settings: Clash tab = Mihomo config,
  Router tab = OpenWrt firewall/dnsmasq. Not grouped by feature type.
- **Log settings on the Log page**, not in Settings.
- **Dashboard settings in Clash tab** — controller port, API secret,
  HTTP/HTTPS, and dashboard install are all co-located.
- **System = maintenance actions** (buttons you press occasionally) +
  startup config. Not folded into Settings because it is action-oriented,
  not declarative.
- **No stream_enhance tab** (streaming unlock excluded).
- **No chnroute tab** (chnroute excluded).
- **No IPv6 tab** (IPv6 proxy excluded in v1).
- **No rules_update tab** (empty in OpenClash source, not implemented).

---

## Change Control

- If a new setting is added, assign it to a tab/page using the
  responsibility principle above. Update this document first.
- The subscription auto-update schedule placement (Sources page) is
  earmarked for review post-implementation.
