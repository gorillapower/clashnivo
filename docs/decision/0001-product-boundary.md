# Product Boundary

Status: Settled

## Purpose

Define the product boundary, scope policy, and coexistence rules for Clash Nivo
(clashnivo) — a LuCI plugin for managing the Mihomo (Clash Meta) proxy binary
on OpenWrt routers.

## Decisions

### Product Shape

Clashnivo is a single OpenWrt package (`luci-app-clashnivo`) that:
- Installs and runs Mihomo (Clash Meta) as a transparent proxy on an OpenWrt router.
- Presents a dead-simple, English-first LuCI UI requiring no prior Clash knowledge.
- Lets users inject customisations (servers, groups, rules, YAML overwrite) into
  downloaded subscription configs without ever editing YAML by hand.

Internal concerns that matter for implementation:
- Config assembly happens at startup via shell scripts that read UCI and emit YAML,
  then merge into the subscription config using Ruby YAML parsing.
- All runtime state is ephemeral (/tmp); persistent state lives in UCI + /etc/clashnivo/.
- The Mihomo binary exposes a REST API used for the external dashboard.

### Scope Rules

**Included:**
- Subscription download and refresh (one or more subs, per-sub schedule).
- Custom proxy server forms: SS, VMess, VLess, Trojan, Hysteria2 only.
- Custom proxy group forms: select / url-test / fallback / load-balance types.
- Config overwrite: a single YAML snippet merged last before binary start.
- Custom rules: a list of individual Clash rules prepended to the subscription rule set.
- Rule providers: external rule-set YAML files (geoip / geosite / custom domain lists)
  referenced from rules by name. Uploaded locally or fetched by URL on a schedule.
- Proxy mode selection: rule / global / direct.
- Transparent proxy mode: fake-ip and redir-host (TUN mode deferred to a later epic).
- DNS configuration: redirect mode (dnsmasq / firewall), upstream DNS servers
  (nameserver + fallback groups), fake-ip filter list.
- Port configuration: mixed-port, http, socks, tproxy, controller (API).
- Mihomo binary management: check installed version, download/update core.
- Status overview: running / stopped, active config, current mode, API link.
- Log viewer: live-tail of /tmp/clashnivo.log.
- Firewall/iptables integration: same iptables/nftables approach as OpenClash
  (copied and renamed scripts).

**Excluded (explicit out-of-scope):**
- ShadowsocksR (SSR) — niche, complex, excluded from server forms.
- Chnroute / China IP split-routing features — region-specific, dropped entirely.
- Streaming-unlock test tool.
- LightGBM smart group and associated ML tooling.
- Developer settings panel.
- Debug DNS / connection diagnostic tools.
- Proxy-provider (external proxy-node YAML files) — deferred post-v1. Subscriptions
  cover the common case; proxy-providers are a power-user lift for later.
- IPv6 proxy (deferred — not in initial scope).
- WireGuard, TUIC, Snell, Mieru, Sudoku, MASQUE, TrustTunnel, and other exotic
  server types — only SS/VMess/VLess/Trojan/Hysteria2 in v1.

### Ownership Rules

- Clashnivo owns the `/etc/clashnivo/` directory exclusively.
- Clashnivo owns the `clashnivo` UCI config (`/etc/config/clashnivo`).
- Clashnivo owns the `/etc/init.d/clashnivo` service.
- Clashnivo does NOT read or write any `/etc/openclash/` path.
- Clashnivo does NOT read or write the `openclash` UCI config.
- If OpenClash is installed, both can run simultaneously on different ports; there
  is no dependency or coordination between them.
- The Mihomo binary is stored at `/etc/clashnivo/core/clash_meta`. Clashnivo
  manages this binary independently; it does not share it with OpenClash.
- Iptables/nftables chain names must use the `CLASHNIVO` prefix (not `CLASH`) to
  avoid collisions.

### Documentation Rule

- Later implementation work must treat this document as the source of truth for
  durable scope and boundary rules.
- If a later task needs to change one of these rules, update this document
  first instead of silently changing code behavior.

## Notes

- The four customisation features (custom servers, custom groups, config overwrite,
  custom rules) are the primary reason for the app's existence. They must be
  prominently accessible, not buried.
- All proxy groups use `include-all-proxies: true`. No manual proxy-to-group
  assignment. Groups expose a `filter:` regex field to narrow the proxy set.
  This applies to both subscription-imported groups and custom groups. This is a
  deliberate, durable deviation from OpenClash's per-server group-assignment model.
- OpenClash stores servers/groups in UCI (`config servers`, `config groups`). We
  copy this approach but scope it: clashnivo's servers/groups are always applied to
  the active config, not scoped per-config-file.
- The "inject without modifying the subscription" invariant is critical: the raw
  downloaded subscription is cached separately; the assembled working config is a
  derived artifact regenerated on every start/reload.
