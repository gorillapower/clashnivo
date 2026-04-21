# Script Inventory

Status: Settled (Pre-Build Audit output #1)

## Purpose

For every shell/Ruby script we intend to copy or fork from OpenClash, record:
what the upstream original does, whether Clash Nivo copies or forks it, and —
if forked — exactly what changes. This is the reference the Epic 0 scaffold
tickets work from.

Source reference: `~/dev/Personal/OpenClash/luci-app-openclash/`.

---

## Summary Table

| Target path in clashnivo | Origin | Lines | Decision | Risk |
|---|---|---|---|---|
| `root/etc/init.d/clashnivo` | `root/etc/init.d/openclash` | 4041 | Fork (heavy) | High |
| `root/usr/share/clashnivo/clashnivo.sh` | `root/usr/share/openclash/openclash.sh` | 460 | Fork | Medium |
| `root/usr/share/clashnivo/yml_proxys_set.sh` | `yml_proxys_set.sh` | 1871 | Fork (cut + rename only) | Low |
| `root/usr/share/clashnivo/yml_groups_set.sh` | `yml_groups_set.sh` | 332 | Fork (major rewrite) | Medium |
| `root/usr/share/clashnivo/clashnivo_yml_change.sh` | `yml_change.sh` | 807 | Fork (pruning) | Medium |
| `root/usr/share/clashnivo/clashnivo_yml_rules_change.sh` | `yml_rules_change.sh` | 420 | Fork (pruning) | Low |
| `root/usr/share/clashnivo/clashnivo_core.sh` | `openclash_core.sh` | 187 | Fork | High (arch detection) |
| `root/usr/share/clashnivo/clashnivo_version.sh` | `openclash_version.sh` | 66 | Fork | Low |
| `root/usr/share/clashnivo/clashnivo_update.sh` | `openclash_update.sh` | 388 | Fork | Medium |
| `root/usr/share/clashnivo/clashnivo_watchdog.sh` | `openclash_watchdog.sh` | 431 | Fork | Medium |
| `root/usr/share/clashnivo/ruby.sh` | `ruby.sh` | 297 | Copy | — |
| `root/usr/share/clashnivo/uci.sh` | `uci.sh` | 5 | Copy | — |
| `root/usr/share/clashnivo/log.sh` | `log.sh` | 60 | Copy | — |
| `root/usr/share/clashnivo/clashnivo_ps.sh` | `openclash_ps.sh` | 71 | Copy | — |
| `root/usr/share/clashnivo/clashnivo_curl.sh` | `openclash_curl.sh` | 93 | Copy | — |
| `root/usr/share/clashnivo/clashnivo_etag.sh` | `openclash_etag.sh` | 92 | Copy | — |
| `root/usr/share/clashnivo/clashnivo_custom_domain_dns.sh` | `openclash_custom_domain_dns.sh` | 42 | Copy | — |
| `root/usr/share/clashnivo/clashnivo_get_network.lua` | `openclash_get_network.lua` | 184 | Copy (1 line change) | — |
| `root/usr/share/clashnivo/YAML.rb` | `YAML.rb` | 441 | Copy verbatim | — |

**Copy** = only string substitution (`openclash`→`clashnivo`, `CLASH`→`CLASHNIVO`,
path renames). **Fork** = logic changes beyond substitution.

**Standard substitutions applied to every copy/fork**, per `repo-layout.md`:

- `openclash` → `clashnivo` (UCI config, paths, chain prefix, log prefix)
- `OpenClash` → `Clash Nivo` (UI labels, log messages)
- `CLASH_` → `CLASHNIVO_` (iptables/nftables chain names)
- `/etc/openclash/` → `/etc/clashnivo/`
- `/usr/share/openclash/` → `/usr/share/clashnivo/`
- `/tmp/openclash*` → `/tmp/clashnivo*`
- `/tmp/lock/openclash*` → `/tmp/lock/clashnivo*`

These are assumed throughout the per-script notes below — not repeated each time.

---

## 1. `init.d/clashnivo` (fork of `init.d/openclash`)

The procd init script. 4041 lines. Contains the full start/stop/reload
pipeline, firewall rule generation, DNS hijacking, watchdog supervision, and
cron scheduling.

### Keep verbatim (string substitution only)

- Lock + startup skeleton: `boot()`, `start_service()`, `stop_service()`,
  `reload_service()`, `start_watchdog()`.
- `check_core_status()` — procd health monitor wrapper.
- `start_run_core()` — core binary invocation.
- `add_cron()` / `del_cron()` — cron scaffolding (but drop the chnroute /
  lgbm cron lines; see below).
- `save_dnsmasq_server()` / `set_dnsmasq_server()` — DNS server injection.
- `revert_firewall()`, `revert_dnsmasq()`, `revert_dns()` — stop-time cleanup.
- `config_choose()`, `config_check()`, `check_run_quick()`, `write_run_quick()`.

### Rewrite

- `do_run_mode()` — strip the TUN branches (`fake-ip-tun`, `redir-host-tun`,
  `fake-ip-mix`, `redir-host-mix`). Keep only base `fake-ip` and `redir-host`.
- `do_run_file()` — remove the chnroute symlink logic and the LightGBM model
  symlink. Remove the `openclash_chnroute.sh` invocations.
- `firewall_lan_ac_traffic()` — extract IPv4-only path. The function has a
  large IPv6 branch (roughly lines 1934–2162 in the original); drop it. Keep
  LAN access-control (black/whitelist IPs and MACs).
- `set_firewall()` — the fw3/fw4 dispatcher, ~1740 lines. Remove all chnroute
  rule emission (`china_ip_route` / `china_ip6_route` iterations) and the
  IPv6 rule blocks. Keep the IPv4 nftables + iptables paths and the
  `CLASHNIVO_` chain prefix rename.
- `get_config()` — UCI key loader. Drop every LightGBM, smart-group,
  chnroute, streaming-unlock, and IPv6-proxy key. See the UCI schema doc
  (audit output #2) for the surviving key set.
- `start_service()` — remove the parameters passed to `yml_change.sh` and
  `yml_rules_change.sh` that carry LightGBM / smart / `fakeip_range6`
  arguments. Adjust to the pruned argument contract of
  `yml_rules_change.sh`.
- `stop_service()` — drop the `openclash_streaming_unlock.lua` kill and the
  chnroute cleanup. Keep the process stop + firewall flush.

### Drop entirely

- `load_ip_route_pass()` and any china_ip_route logic.
- All `openclash_chnroute.sh`, `openclash_geoasn.sh`, `openclash_ipdb.sh`
  cron scheduling. Keep `geoip` / `geosite` update cron only if we decide to
  keep GEO auto-update (it is in Epic 5; wire it later).
- All `smart_*`, `lgbm_*`, `stream_auto_select_*`, `skip_proxies_address`
  branches.
- Chinese log strings throughout (every `【...】`-delimited phrase).

### External script calls (post-fork)

The init script will source/execute: `clashnivo.sh`, `clashnivo_core.sh`,
`clashnivo_yml_change.sh`, `clashnivo_yml_rules_change.sh`,
`clashnivo_watchdog.sh`, `clashnivo_custom_domain_dns.sh`,
`clashnivo_get_network.lua`, `clashnivo_ipdb.sh`, `clashnivo_geosite.sh`,
`clashnivo_geoip.sh`, `clashnivo_geoasn.sh`, `ruby.sh`, `log.sh`, `uci.sh`,
`clashnivo_ps.sh`, `clashnivo_curl.sh`. Note: `clashnivo_yml_change.sh`
(Stage 7 global config modifier) is called directly from `start_service` —
it is a required Epic 0 scaffold item, not optional. The OpenClash-only
dependencies dropped are `openclash_chnroute.sh`,
`openclash_streaming_unlock.lua`, `openclash_history_get.sh`,
`openclash_lgbm.sh`, `openclash_debug*.*`.

### Risk notes

- IPv6 and chnroute logic is interleaved with IPv4 rule generation. Extracting
  cleanly without breaking IPv4 rules is the single biggest risk in Epic 0.
  Validate with `nft list ruleset` + iptables-save snapshots before/after on
  both fw3 and fw4 routers.
- Chain-prefix rename must be exhaustive. Any missed `CLASH_` reference
  creates a silent conflict with a co-installed OpenClash.
- `/etc/openclash` path rename appears ~50+ times; a missed occurrence
  silently reads OpenClash's files.
- **dnsmasq snapshot race (coexistence edge case):** `save_dnsmasq_server()`
  snapshots the current dnsmasq state into UCI at start time. If OpenClash
  crashed without reverting its dnsmasq changes, clashnivo's snapshot captures
  the OpenClash-modified state as "original." On clashnivo stop, `revert_dns()`
  restores that corrupted baseline, leaving dnsmasq pointing at a dead port.
  This is an inherent multi-proxy-app limitation on OpenWrt, not unique to us.
  **Mitigation: implemented.** `save_dnsmasq_server()` in the fork rejects any
  `127.0.0.1#*` address — not just our own `dns_port` — and emits a `LOG_WARN`
  identifying the discarded entry. This is broader than strictly needed (it
  would also reject a legitimate self-hosted dnsmasq-to-dnsmasq setup on
  127.0.0.1), but matches the intent: no proxy pointer should ever be treated
  as "original" state.

---

## 2. `clashnivo.sh` (fork of `openclash.sh`)

Subscription download + assembly orchestrator. 460 lines.

### Keep

- `config_download()`, `config_test()`, `config_su_check()` — curl pipeline,
  clash-binary validation, change detection.
- `sub_info_get()` main loop — UCI iteration, URL construction including
  sub-converter template logic.
- Ruby invocation scaffold for YAML parse and per-subscription filtering.
- Lock mechanism at `/tmp/lock/clashnivo_subs.lock`.

### Rewrite / cut

- Remove `kill_streaming_unlock()` and the `only_download=1` fallback that
  exists as a streaming-unlock workaround.
- Strip Chinese log prefixes.
- Keyword include/exclude filter (`keyword`, `ex_keyword`) — **keep** for
  Clash Nivo. This is Stage 2 of the pipeline per `system-pipeline.md`.
  Earlier scoping notes considered dropping it, but the pipeline doc
  settles: include-all-proxies replaces manual group assignment, not
  subscription-level filtering.

### Risk notes

- `config_download_direct()` fallback requires router self-proxy mode; it is
  inherently fragile but worth keeping because it is the only path that works
  when the sub URL is blocked without going through the proxy.

---

## 3. `yml_proxys_set.sh` (fork)

1871 lines. Reads UCI `servers` and `proxy-provider` sections, emits
`/tmp/yaml_servers.yaml` and `/tmp/yaml_provider.yaml`, then merges via
`ruby_cover` into the active config's `proxies:` and `proxy-providers:` keys.

### Protocol blocks — keep

SS (lines ~270–396), VMess (~434–619), VLess (~1117–1286), Trojan
(~1446–1516), Hysteria2 (~997–1115). These are the five protocols Clash Nivo
supports.

### Protocol blocks — remove entirely

SSR (~399–432), Snell (~1519–1545), Sudoku (~1547–1593), SSH (~1309–1357),
SOCKS5 (~1358–1400), HTTP (~1401–1445), WireGuard (~818–876), TUIC
(~717–816), Mieru (~682–715), AnyTLS (~621–679), Hysteria v1 (~877–995),
TrustTunnel (~1653–1700), MASQUE (~1594–1651). Also the `dns` and `direct`
utility type blocks (~1288–1307) unless a concrete need surfaces — default
to cut.

### Keep

Helper functions `set_alpn`, `set_ws_headers`, `set_ip_version`, `set_tfo`,
`set_dialer_proxy`. The `ruby_cover` merge at the end.

### Rewrite

None. Group-filter logic lives in `yml_groups_set.sh`; this script is pure
per-protocol YAML emission.

### Risk notes

- The final-stage fallback at the very bottom (the `cat` concat if
  `ruby_cover` fails) naively concatenates YAML files. If any part file
  contains its own top-level `---` document separator, the result is
  invalid. Worth replacing the fallback with a fail-loud error.

---

## 4. `yml_groups_set.sh` (fork — major rewrite)

332 lines. Generates `/tmp/yaml_groups.yaml` from UCI `groups` sections.
**This is the most substantive logic change in the scaffold.**

### The rewrite

OpenClash populates each group's `proxies:` list by regex-matching UCI
`groups:` list-option values against server names, then writing each
matched name explicitly into the YAML. This is the `set_groups()` and
`set_provider_groups()` functions and the `config_list_foreach "groups" ...`
invocations throughout.

Clash Nivo replaces all of that with Clash-native syntax:

```yaml
- name: Auto
  type: url-test
  include-all-proxies: true
  filter: "(?i)hk|hong.?kong"
  exclude-filter: "info|expire"
  url: http://www.gstatic.com/generate_204
  interval: 300
```

That means:

- Delete `set_groups()` (lines ~45–61) and `set_provider_groups()` (~181–196).
- Delete every `config_list_foreach "$section" "groups" set_groups "$name"`
  (lines 82, 155, 176, 246).
- Simplify the placeholder-sed logic (~254–269) — the `proxies:` line becomes
  a static `include-all-proxies: true` plus optional `filter` and
  `exclude-filter` lines.
- `policy_filter` UCI key becomes `filter` directly; add a new
  `exclude_filter` UCI key (see UCI schema doc).

### Keep

- Group scaffold (name, type, test URL, interval, tolerance, strategy, UDP,
  interface-name, routing-mark, icon, `other_parameters`).
- Utility group injection (DIRECT, REJECT, PASS, GLOBAL).
- Group types: `select`, `url-test`, `fallback`, `load-balance`.

### Drop

- `smart` group type and the entire LightGBM block (~300–310).
- `uselightgbm`, `collectdata`, `policy_priority` UCI reads.

### Semantic note

This is a deliberate deviation from OpenClash. It is the core of the
product boundary and is settled in `docs/decision/0001-product-boundary.md`.

---

## 5. `yml_rules_change.sh` (fork — pruning)

420 lines. Embedded Ruby block that mutates the assembled config: prepends
BT/PT DIRECT rules, prepends custom rules from
`/etc/clashnivo/custom/*.list`, applies CDN URL rewrites, and overrides
url-test intervals.

### Keep

- **BT/PT DIRECT injection** (lines ~26–104). Explicitly listed in
  `repo-layout.md` as a transitional keep.
- Custom rule injection (~117–247) — the list-file → rules-array prepend.
- Rule validation loop (~167–198) — checks that rule target groups exist.
- Provider path normalization (~272–306).
- CDN URL rewrite (~285–302) — GitHub → jsDelivr / Fastly mirror fallback.
- URL-test interval/tolerance overrides (~311–350).

### Drop

- Smart group auto-switch (~378–407). Clash Nivo has no smart groups.
- Router self-proxy rule injection (~249–265). The stateless config model
  does not need it.
- All positional args related to smart / LightGBM (`$8`–`$13`). Adjust the
  init-script call site accordingly.
- All Chinese comments.

### Risk notes

- The mutation is in-place (`File.open($2, 'w') { |f| YAML.dump(Value, f) }`).
  A thread exception during mutation can corrupt the config. The `ensure`
  block mitigates but does not eliminate this. Confirm the pattern survives
  the prune.

---

## 6. `clashnivo_core.sh` (fork of `openclash_core.sh`)

Downloads the Mihomo binary. 187 lines.

### Drop

- All non-Meta branches: original Clash, Clash Premium, TUN-Premium, Dev,
  Alpha, Smart-enable.
- `core_type`, `smart_enable` UCI keys.

### Rewrite

- Download URL pattern. OpenClash uses its own mirror at
  `raw.githubusercontent.com/vernesong/OpenClash/core/…`. Clash Nivo must
  point at upstream Mihomo releases:
  `https://github.com/MetaCubeX/mihomo/releases/download/v<VERSION>/mihomo-<ARCH>-v<VERSION>.gz`.
  Exact asset naming must be verified against a recent Mihomo release
  before Epic 4.
- Arch map. Mihomo assets are named `linux-amd64`, `linux-arm64`,
  `linux-armv7`, `linux-386`, `linux-mips-softfloat`,
  `linux-mipsle-softfloat`, etc. Map OpenWrt arch detection to these.
- Binary target path: `/etc/clashnivo/core/mihomo` (not `clash_meta`).

### Keep

- Lock, retry loop, gzip validation, tar extraction, chmod, binary `-v`
  verification. procd job-counter restart signalling.

### Risk notes

- **Highest-risk single item in the scaffold.** Arch detection must work
  on mips / mipsel / arm / armv7 / arm64 / x86 / x86_64 OpenWrt routers.
  Validate on at least two real devices before Epic 0 sign-off.
- No SHA256 verification today — only gzip test. Worth adding during the
  fork (Mihomo releases publish SHA256 alongside assets).

---

## 7. `clashnivo_version.sh` (fork of `openclash_version.sh`)

66 lines. Checks the latest luci-app package version. Trivial to fork.

- Rename the output file to `/tmp/clashnivo_last_version`.
- Repoint the version URL to Clash Nivo's own release channel (TBD — this
  requires deciding where we publish packages; mark as **Open Question**).
- Note: this script is about the LuCI package itself, not the Mihomo core.
  A separate invocation (inline in `clashnivo_core.sh`) handles the Mihomo
  version check.

---

## 8. `clashnivo_update.sh` (fork of `openclash_update.sh`)

388 lines. Self-updates the LuCI package via opkg/apk.

### Keep

- Lock, retry, version comparison, opkg/apk pre-test (`--noaction`),
  async install via procd service spawn, trap-based cleanup.

### Rewrite

- Package URL pattern (depends on the Clash Nivo package repo decision).
- Package name: `luci-app-clashnivo` instead of `luci-app-openclash`.

### Drop

- "One-key update" chained Mihomo core update unless we want this in Epic 4
  (defer the decision; easier to keep as a togglable branch).
- Chinese comments.

---

## 9. `clashnivo_watchdog.sh` (fork of `openclash_watchdog.sh`)

431 lines. 60-second loop: health-checks Mihomo, maintains firewall rules,
keeps dnsmasq hijack, syncs localnetwork sets, maintains UPNP leases.

### Keep

- Main loop skeleton, log rotation, procd ubus health check, localnetwork
  set refresh (IPv4), UPNP lease handling, dnsmasq hijack refresh,
  firewall rule-order sanity check and reload-on-drift.

### Drop

- Ruby `skip_proxies_address()` (~lines 17–144). Removes a hard Ruby
  dependency in the watchdog path.
- Streaming-unlock auto-select block (~370–427) and all
  `stream_auto_select_*` UCI keys.
- Config auto-update cron tick (~362–368) — handled via the dedicated
  cron entry in init.d instead.
- IPv6 localnetwork set refresh and any `ipv6_*` branches.

### Rewrite

- Process match pattern must target `mihomo` / `/etc/clashnivo/core/mihomo`
  (not `/etc/openclash/clash*`).
- Firewall reload callback: `/etc/init.d/clashnivo reload firewall`.
- Localnetwork set names: `clashnivo_localnetwork` (matches the chain
  prefix rename).

### Risk notes

- No internal lock. Only one procd instance runs, so concurrency is not
  expected, but document the assumption.
- `dnsmasq` restart on drift can clobber a user's manual DNS changes.
  Acceptable trade-off, same as OpenClash.

---

## 10. Direct copies

These files need only string substitution and the standard path renames.
No logic review required beyond the notes below.

### `ruby.sh`

Shell wrappers around Ruby YAML manipulation. The public contract:

| Function | Purpose |
|---|---|
| `ruby_cover` | Replace YAML subtree with content from another file |
| `ruby_merge` | Deep-merge Hash from external file into target path |
| `ruby_merge_hash` | Inline Hash merge into target |
| `ruby_read` / `ruby_read_hash` / `ruby_read_hash_arr` | Read values by path |
| `ruby_edit` | Set scalar or Hash value at path |
| `ruby_uniq` | Deduplicate array at path |
| `ruby_arr_add_file` / `ruby_arr_head_add_file` | Append / prepend array from file |
| `ruby_arr_insert` / `ruby_arr_insert_hash` / `ruby_arr_insert_arr` | Insert at index |
| `ruby_delete` | Remove key or array element |
| `ruby_map_edit` / `ruby_arr_edit` | Bulk edit nested fields |
| `write_ruby_part` / `run_ruby_part` | Queue/apply snippets under overwrite mode |
| `openclash_custom_overwrite` | Detect overwrite-script execution context (rename to `clashnivo_custom_overwrite`) |

Requires `YAML.rb` in the same directory.

### `uci.sh`

Five lines. The `uci_get_config` helper with config/overwrite fallback.

### `log.sh`

Logging helpers — `LOG_OUT`, `LOG_TIP`, `LOG_WARN`, `LOG_ERROR`, `LOG_INFO`,
`LOG_WATCHDOG`, `LOG_ALERT`, `SLOG_CLEAN`. Writes to
`/tmp/clashnivo_start.log` and `/tmp/clashnivo.log`. The `LOG_ALERT` grep
pattern (`level=fatal|level=error`) is Mihomo's log format and is correct
as-is.

### `clashnivo_ps.sh` (fork of `openclash_ps.sh`)

Process utilities. Cross-busybox/procps-ng `ps` normalization, flock-based
job counter, restart orchestration. Functions: `unify_ps_status`,
`unify_ps_pids`, `unify_ps_prevent`, `unify_ps_cfgname`, `inc_job_counter`,
`dec_job_counter_and_restart`.

Treat as fork, not copy, because the process-match patterns reference
`/etc/openclash/clash` and `/etc/init.d/openclash` directly; the path
renames are a one-line change per pattern but are semantic (not pure
substitution), so audit the rename carefully.

### `clashnivo_curl.sh` (fork of `openclash_curl.sh`)

`DOWNLOAD_FILE_CURL` wrapper with ETag caching and progress feedback.
Depends on `clashnivo_etag.sh`.

### `clashnivo_etag.sh` (copy of `openclash_etag.sh`)

92 lines. ETag cache library for conditional HTTP downloads. Functions:
`GET_ETAG_BY_PATH`, `GET_ETAG_TIMESTAMP_BY_PATH`, `SAVE_ETAG_TO_CACHE`,
`LIST_ETAG_CACHE`. Single path dependency:
`ETAG_CACHE="/etc/openclash/history/etag"` → `/etc/clashnivo/history/etag`.
No logic changes. Decision: **copy**.

### `clashnivo_custom_domain_dns.sh` (copy of `openclash_custom_domain_dns.sh`)

42 lines. Writes per-domain DNS server overrides into the active dnsmasq
`conf-dir` as `dnsmasq_clashnivo_custom_domain.conf`. Reads UCI keys
`enable_custom_domain_dns_server`, `enable_redirect_dns`,
`custom_domain_dns_server`, and list file
`/etc/clashnivo/custom/clashnivo_custom_domain_dns.list`. Pure path + UCI
substitution. Decision: **copy**.

### `clashnivo_get_network.lua` (copy of `openclash_get_network.lua`)

184 lines. LuCI Lua script that detects WAN interface properties (IP,
gateway, DNS, proto, CIDR). Called by init.d and watchdog with a type
argument (`dns`, `gateway`, `dhcp`, `pppoe`, `wanip`, `lan_cidr`, and IPv6
variants). The IPv6 type branches (`dns6`, `gateway6`, `wanip6`,
`lan_cidr6`) are passive — they only respond if the caller passes that type
argument. Since we're removing IPv6 proxy support from init.d, we simply
won't call those types; the branches are harmless and can stay.

One dependency rename required: `require "luci.openclash"` → `require
"luci.clashnivo"` (line 8). That single change is the reason this is listed
as a fork in `repo-layout.md`. Everything else is standard LuCI network
API. Decision: **copy** (effectively).

### `YAML.rb`

441-line Ruby module. Extends `YAML` with logging helpers and a short-id
quote-preservation fix required for Reality configs. Pure Ruby, no path
dependencies. Copy verbatim; do not rename or modify.

---

## Open Questions (resolved and unresolved)

### Resolved

**Q2 — `openclash_etag.sh`:** Audited. Simple ETag cache library, no excluded
features. Decision: copy with path rename. Added to inventory above and to
Epic 0 scope.

**Q3 — `openclash_custom_domain_dns.sh`:** Audited. 42-line script, pure
dnsmasq conf-dir writer. The custom-domain-to-DNS-server feature is in scope
(it is a useful DNS configuration primitive, not a chnroute/streaming feature).
Decision: copy with path + UCI substitution. Added to inventory and Epic 0 scope.

**Q4 — `openclash_get_network.lua`:** Audited. 184 lines, standard LuCI
network API wrapper. The only clashnivo-specific change is the `require`
path on line 8. IPv6 query branches are passive and left in place; init.d
simply won't invoke them. Decision: copy (single require rename). Added to
inventory above.

**Q5 — GEO data auto-update scripts:** Deferred to Epic 5. No decision
needed now. The GEO files themselves (geoip.dat, geosite.dat) are shipped
as-is from upstream; only the auto-update scheduling is deferred.

**Q6 — SHA256 verification for Mihomo downloads:** Resolved as: add during
the `clashnivo_core.sh` fork in Epic 0. Mihomo GitHub releases publish a
`mihomo-<ARCH>-v<VERSION>.gz.sha256` file alongside each asset. The fork
ticket should include a `sha256sum -c` step after download, before
extraction.

**Q1 — Package release URL:** Resolved. The project repo is
`github.com/gorillapower/clashnivo` (public). Package releases will be
published as GitHub Releases on that repo. `clashnivo_version.sh` should
check the GitHub Releases API at:
`https://api.github.com/repos/gorillapower/clashnivo/releases/latest`
and download the `.ipk` / `.apk` asset from the release assets list.
This mirrors how other OpenWrt community packages self-update. Not blocking
Epic 0; wire this in during Epic 4.

---

## What next

Audit output #2 — UCI schema definition — depends on this file. Every
`uci_get_config` key identified across the scripts above must appear in the
schema with a declared type, default, and owning pipeline stage. That
document is the source of truth for `/etc/config/clashnivo` defaults and
for the CBI settings page.
