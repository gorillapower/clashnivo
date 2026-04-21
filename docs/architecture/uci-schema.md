# UCI Schema

Status: Settled (Pre-Build Audit output #2)

## Purpose

Defines every key in `/etc/config/clashnivo`: section type, option name, type,
default, and which pipeline stage reads it. This is the source of truth for:

- `/etc/config/clashnivo` factory defaults (shipped in the package)
- `uci-defaults/luci-clashnivo` first-boot initialisation
- Every `uci_get_config` call site in the forked shell scripts
- Every CBI option in `luasrc/model/cbi/clashnivo/`
- The rpcd ACL grants for the controller

Cross-references: `script-inventory.md` (audit #1) names the scripts that read
each key. `system-pipeline.md` defines the ten-stage assembly that consumes
them. Source reference is OpenClash at
`~/dev/Personal/OpenClash/luci-app-openclash/`. All keys below are renamed from
`openclash.*` to `clashnivo.*`.

---

## Section Type Overview

| Section type | Instance count | Named? | Purpose | Owning CBI |
|---|---|---|---|---|
| `clashnivo` (type `config`, named `config`) | 1 | named singleton | Global settings | `settings.lua`, `overview.lua` |
| `config_subscribe` | 0..N | named | One subscription entry | `subscription.lua`, `subscription-edit.lua` |
| `servers` | 0..N | named | One custom proxy node | `custom-servers.lua`, `custom-servers-edit.lua` |
| `groups` | 0..N | named | One custom proxy group | `custom-groups.lua`, `custom-groups-edit.lua` |
| `dns_servers` | 0..N | anonymous | One DNS upstream entry | `settings.lua` (DNS tab) |
| `config_overwrite` | 0..N | named | One overwrite source | `config-overwrite.lua` |
| `rule_provider` | 0..N | named | One rule-set provider (geoip/geosite/custom) | `custom-rules.lua` (shared page with rule items) |
| `lan_ac_traffic` | 0..N | named | One LAN AC traffic rule | `settings.lua` (LAN AC tab) |
| `authentication` | 1 | anonymous | Dashboard API auth | `settings.lua` (Dashboard tab) |

`proxy_provider` from OpenClash is **DEFERRED** post-v1 (see
`docs/decision/0001-product-boundary.md`). `rule_provider` was previously
deferred alongside proxy-provider but has been promoted to v1 scope —
rule-sets are essential for practical rule list authoring.

---

## Pipeline-Stage Matrix

Quick lookup: which script reads each section at which stage (stages from
`system-pipeline.md`).

| Section | Stage 1 DL | Stage 2 filter | Stage 3 proxies | Stage 4 groups | Stage 5 rules | Stage 6 overwrite | Stage 7 globals | Stage 8 start | Stage 9 DNS | Stage 10 firewall | Watchdog |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `clashnivo.config` | ✓ | — | — | — | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `config_subscribe` | ✓ | ✓ | — | — | — | — | — | — | — | — | — |
| `servers` | — | — | ✓ | — | — | — | — | — | — | — | — |
| `groups` | — | — | — | ✓ | — | — | — | — | — | — | — |
| `dns_servers` | — | — | — | — | — | — | ✓ | — | — | — | — |
| `config_overwrite` | — | — | — | — | — | ✓ | — | — | — | — | — |
| `rule_provider` | — | — | — | — | ✓ | — | — | — | — | — | — |
| `lan_ac_traffic` | — | — | — | — | — | — | — | — | — | ✓ | — |
| `authentication` | — | — | — | — | — | — | ✓ | ✓ | — | — | — |

---

## 1. `clashnivo.config` (singleton)

Named section: `config`. All global settings live here. Factory defaults shown
are what `/etc/config/clashnivo` ships with. Auto-generated defaults (e.g.
`dashboard_password`, `core_version` arch string) are set by
`uci-defaults/luci-clashnivo` on first boot.

### 1.1 Identity & lifecycle

| Key | Type | Default | Purpose | Read by (stage) |
|---|---|---|---|---|
| `enable` | bool | `0` | Service enabled master switch | init.d start (8) |
| `config_path` | string | — | Active subscription filename (e.g. `my-sub.yaml`) | init.d (1, 8), `clashnivo.sh` (1) |
| `delay_start` | int (seconds) | `0` | Wait N seconds before starting after boot | init.d (8) |
| `operation_mode` | enum | `fake-ip` | `fake-ip` \| `redir-host` | init.d (8), firewall (10) |
| `en_mode` | enum | `fake-ip` | Alias of `operation_mode` (legacy; see **Open Q1**) | init.d (8) |
| `proxy_mode` | enum | `rule` | `rule` \| `global` \| `direct` (Clash-level mode) | Stage 7 YAML write |
| `log_level` | enum | `info` | `silent` \| `error` \| `warning` \| `info` \| `debug` | Stage 7 YAML write |
| `log_size` | int (KB) | `1024` | Log rotation threshold | init.d log rotation |

### 1.2 Ports

All default ports diverge from OpenClash by design to allow side-by-side
coexistence. **Final port numbers TBD** — current values mirror OpenClash and
must be changed before release (see **Open Q2**).

| Key | Type | Default | Purpose | Read by |
|---|---|---|---|---|
| `mixed_port` | port | `7993` | HTTP+SOCKS5 mixed | Stage 7 |
| `http_port` | port | `7990` | HTTP proxy | Stage 7 |
| `socks_port` | port | `7991` | SOCKS5 proxy | Stage 7 |
| `proxy_port` | port | `7992` | Transparent redir (redir-host) | Stage 7, firewall (10) |
| `tproxy_port` | port | `7995` | Transparent TPROXY (UDP) | Stage 7, firewall (10) |
| `dns_port` | port | `7974` | Mihomo internal DNS | Stage 7, firewall (9) |
| `cn_port` | port | `9190` | External controller / REST API | Stage 7, overview status |
| `common_ports` | string | `0` | Optional narrow port list (`0` = all) | Firewall (10) |

### 1.3 DNS

| Key | Type | Default | Purpose | Read by |
|---|---|---|---|---|
| `enable_redirect_dns` | enum | `1` | `0` Off \| `1` Dnsmasq redirect \| `2` Firewall redirect | Stage 9 |
| `fakeip_range` | CIDR | `198.18.0.0/15` | Mihomo fake-IP pool | Stage 7 |
| `store_fakeip` | bool | `0` | Persist fake-IP map across restarts | Stage 7 |
| `enable_custom_dns` | bool | `0` | Use UCI `dns_servers` instead of subscription default | Stage 7 |
| `custom_fakeip_filter` | bool | `0` | Apply custom fake-ip filter list | Stage 7 |
| `custom_fakeip_filter_mode` | enum | `blacklist` | `blacklist` \| `whitelist` | Stage 7 |
| `custom_fallback_filter` | bool | `0` | Apply custom fallback filter list | Stage 7 |
| `custom_host` | bool | `0` | Apply custom hosts list | Stage 7 |
| `custom_name_policy` | bool | `0` | Apply custom nameserver-policy list | Stage 7 |
| `custom_proxy_server_policy` | bool | `0` | Apply custom proxy-server nameserver policy | Stage 7 |
| `append_default_dns` | bool | `0` | Append WAN DNS to upstream list | Stage 7 |
| `append_wan_dns` | bool | `0` | Append WAN nameservers to `nameserver` group | Stage 7 |
| `enable_custom_domain_dns_server` | bool | `0` | Enable per-domain DNS server overrides | Stage 9 (`clashnivo_custom_domain_dns.sh`) |
| `custom_domain_dns_server` | host | `8.8.8.8` | DNS server for custom-domain list | Stage 9 |
| `disable_masq_cache` | bool | `1` | Set dnsmasq cachesize=0 while service runs | Stage 9 |
| `default_resolvfile` | path | (auto) | dnsmasq resolvfile backup (set at first boot) | Stage 9 |
| `redirect_dns` | bool | — | Backup of dnsmasq redirect state (init.d internal) | Stage 9 restore |
| `cachesize_dns` | int | — | Backup of dnsmasq cachesize (init.d internal) | Stage 9 restore |
| `filter_aaaa_dns` | bool | — | Backup of dnsmasq filter-aaaa (init.d internal) | Stage 9 restore |
| `dnsmasq_noresolv` | bool | — | Backup of dnsmasq noresolv | Stage 9 restore |
| `dnsmasq_resolvfile` | string | — | Backup of dnsmasq resolvfile | Stage 9 restore |
| `dnsmasq_cachesize` | int | — | Backup of dnsmasq cachesize | Stage 9 restore |
| `dnsmasq_filter_aaaa` | bool | — | Backup of dnsmasq filter_aaaa | Stage 9 restore |
| `dnsmasq_server` | list(string) | — | Backup of dnsmasq upstream server list | Stage 9 restore |

`dnsmasq_*` keys and `redirect_dns` / `cachesize_dns` / `filter_aaaa_dns` are
**not user-facing**. Init.d writes them on start (snapshot) and reads them on
stop (restore). Do not expose in CBI.

### 1.4 Transparent proxying

| Key | Type | Default | Purpose | Read by |
|---|---|---|---|---|
| `enable_udp_proxy` | bool | `1` | Forward UDP through Mihomo | Stage 10 |
| `disable_udp_quic` | bool | `1` | Block UDP 443 (QUIC) to force TCP fallback | Stage 10 |
| `intranet_allowed` | bool | `1` | Allow LAN access to router ports (dashboard, ssh) | Stage 10 |
| `intranet_allowed_wan_name` | list(string) | — | WAN interface names treated as intranet | Stage 10 |
| `enable_rule_proxy` | bool | `0` | Apply firewall rules on rule mode (vs global only) | Stage 10 |
| `router_self_proxy` | bool | `1` | Route traffic originated *by* the router through proxy | Stage 10 |
| `bypass_gateway_compatible` | bool | `0` | Compatibility bypass for double-NAT gateways | Stage 10 |
| `small_flash_memory` | bool | `0` | Write large files under `/tmp` instead of `/etc` | init.d path selection |
| `disable_quic_go_gso` | bool | `0` | Mihomo env var `QUIC_GO_DISABLE_GSO=true` (kernel ≥6.6 workaround) | init.d env |

**Note on `router_self_proxy`:** the UCI flag is kept and drives firewall rule
generation. The *separate* `yml_rules_change.sh` rule-injection variant is
cut (see `script-inventory.md` §5). Firewall behaviour is unchanged.

### 1.5 LAN access control

| Key | Type | Default | Purpose |
|---|---|---|---|
| `lan_ac_mode` | enum | `0` | `0` blacklist \| `1` whitelist |
| `lan_ac_black_ips` | list(ipmask) | — | Blacklisted source IPs |
| `lan_ac_black_macs` | list(macaddr) | — | Blacklisted source MACs |
| `lan_ac_white_ips` | list(ipmask) | — | Whitelisted source IPs |
| `lan_ac_white_macs` | list(macaddr) | — | Whitelisted source MACs |
| `wan_ac_black_ips` | list(ipmask) | — | WAN-side IP blacklist |
| `wan_ac_black_ports` | list(port\|portrange) | — | WAN-side port blacklist |
| `lan_interface_name` | string | `0` | LAN bridge name override (`0` = auto-detect) |
| `interface_name` | string | `0` | Outbound bind interface override (`0` = auto) |

All read by Stage 10 firewall. Per-entry traffic rules live in the separate
`lan_ac_traffic` section type (§7).

### 1.6 Mihomo feature flags (written into `config.yaml`)

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enable_tcp_concurrent` | bool | `0` | Mihomo `tcp-concurrent: true` |
| `enable_unified_delay` | bool | `0` | Mihomo `unified-delay: true` |
| `enable_respect_rules` | bool | `0` | DNS `respect-rules: true` |
| `enable_meta_sniffer` | bool | `0` | Mihomo traffic sniffer enable |
| `enable_meta_sniffer_custom` | bool | `0` | Custom sniffer rules file |
| `enable_meta_sniffer_pure_ip` | bool | `0` | Sniff pure-IP traffic too |
| `find_process_mode` | enum | `0` | `0` off \| `always` \| `strict` (process-rule matching) |

All read Stage 7.

### 1.7 Binary & dashboard

| Key | Type | Default | Purpose | Read by |
|---|---|---|---|---|
| `core_version` | string | `0` | Target Mihomo arch string (e.g. `linux-arm64`) | `clashnivo_core.sh` |
| `dashboard_type` | enum | `zashboard` | `metacubexd` \| `zashboard` | Stage 7 (`external-ui`) |
| `dashboard_password` | string | auto-generated | REST API secret | Stage 7 |
| `dashboard_forward_domain` | string | `0` | CORS allow-origin list (`0` = default) | Stage 7 |
| `dashboard_forward_ssl` | bool | `0` | Expose REST over HTTPS | Stage 7 |
| `enable_custom_clash_rules` | bool | `0` | Prepend custom rules (`/etc/clashnivo/custom/*.list`) | Stage 5 |

OpenClash's `yacd_type` and `release_branch` are dropped — Clash Nivo ships a
single dashboard set and a single release channel.

### 1.8 URL-test & CDN rewrite

| Key | Type | Default | Purpose | Read by |
|---|---|---|---|---|
| `github_address_mod` | string | `0` | GitHub CDN rewrite prefix (e.g. `testingcf.jsdelivr.net/gh`) | Stage 5 `yml_rules_change.sh` |
| `urltest_address_mod` | string | `0` | Override url-test target URL globally | Stage 5 |
| `urltest_interval_mod` | int (seconds) | `0` | Override url-test interval globally (`0` = keep per-group) | Stage 5 |
| `tolerance` | int (ms) | `0` | Global url-test tolerance override | Stage 5 |

### 1.9 GEO data

| Key | Type | Default | Purpose |
|---|---|---|---|
| `geo_custom_url` | URL | `https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb` | MMDB Country file source |
| `geoip_custom_url` | URL | `https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat` | geoip.dat source |
| `geosite_custom_url` | URL | `https://testingcf.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat` | geosite.dat source |
| `geoasn_custom_url` | URL | `https://testingcf.jsdelivr.net/gh/xishang0128/geoip@release/GeoLite2-ASN.mmdb` | ASN MMDB source |
| `geodata_loader` | enum | `0` | `0` standard \| `memconservative` |
| `enable_geoip_dat` | bool | `0` | Prefer `.dat` over `.mmdb` for GeoIP |
| `geo_auto_update` | bool | `0` | Enable auto-update for MMDB Country |
| `geo_update_day_time` | int (0-23) | — | Hour of day for daily update |
| `geo_update_week_time` | int (0-7) | — | Day of week (`0` = daily) |
| `geoip_auto_update` | bool | `0` | Auto-update geoip.dat |
| `geoip_update_day_time` | int | — | — |
| `geoip_update_week_time` | int | — | — |
| `geosite_auto_update` | bool | `0` | Auto-update geosite.dat |
| `geosite_update_day_time` | int | — | — |
| `geosite_update_week_time` | int | — | — |
| `geoasn_auto_update` | bool | `0` | Auto-update ASN MMDB |
| `geoasn_update_day_time` | int | — | — |
| `geoasn_update_week_time` | int | — | — |

Wired into cron by init.d `add_cron`. All GEO wiring is Epic 5 scope; keys must
be present in the schema from Epic 0 so init.d compiles.

### 1.10 Auto-update (package) & auto-restart

| Key | Type | Default | Purpose |
|---|---|---|---|
| `auto_update` | bool | `0` | Auto-update the active subscription |
| `auto_update_time` | int (0-23) | `0` | Hour for subscription refresh |
| `config_auto_update_mode` | enum | `0` | `0` daily \| `1` weekly \| `2` custom |
| `config_update_week_time` | int (0-7) | `0` | Day of week for weekly mode |
| `config_update_interval` | int (minutes) | `60` | Custom-mode interval |
| `auto_restart` | bool | `0` | Enable scheduled service restart |
| `auto_restart_day_time` | int (0-23) | — | Hour |
| `auto_restart_week_time` | int (0-7) | — | Day of week (`0` = daily) |

Wired into cron by init.d. Epic 5 surfaces these in the UI; Epic 0 must accept
them.

---

## 2. `config_subscribe` (0..N named sections)

One section per subscription. Consumed by `clashnivo.sh` at Stage 1 (download)
and Stage 2 (keyword filter).

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `1` | Process this subscription |
| `name` | string | required | Output filename stem (`<name>.yaml`) |
| `address` | URL | required | Subscription URL (multi-line accepted; joined with `\|`) |
| `sub_ua` | string | `clash.meta` | User-Agent header |
| `sub_convert` | bool | `0` | Route through a subconverter service |
| `convert_address` | URL | `https://api.wcc.best/sub` | Subconverter endpoint |
| `template` | string | `0` | Subconverter template id (`0` = use `custom_template_url`) |
| `custom_template_url` | URL | — | Used when `template = 0` |
| `emoji` | enum (`true`/`false`) | `false` | Subconverter emoji flag |
| `udp` | enum | `false` | Subconverter UDP flag |
| `skip_cert_verify` | enum | `false` | Subconverter cert-verify flag |
| `sort` | enum | `false` | Subconverter sort flag |
| `node_type` | enum | `false` | Subconverter node-type prefix flag |
| `rule_provider` | enum | `false` | Subconverter expanded rule-provider output |
| `custom_params` | list(string) | — | Extra subconverter query params (`key=value`) |
| `keyword` | list(string) | — | Include-only regex filters (Stage 2) |
| `ex_keyword` | list(string) | — | Exclude regex filters (Stage 2) |
| `de_ex_keyword` | multi(string) | — | Preset exclusion tokens (`Expire`, `Traffic`, `Plan`, `Official`) |

No IPv6, chnroute, or streaming-unlock fields in this section.

---

## 3. `servers` (0..N named sections)

One section per custom proxy node. Consumed by `yml_proxys_set.sh` at Stage 3.
`config = all` applies the server to every subscription; otherwise it applies
only to the named config(s).

### 3.1 Common fields (all protocols)

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `1` | Include in active config |
| `config` | list(string) | `all` | Target config filename(s) or `all` |
| `name` | string | required | Proxy name (must be unique within generated YAML) |
| `type` | enum | required | `ss` \| `vmess` \| `vless` \| `trojan` \| `hysteria2` |
| `server` | host | required | Hostname or IP |
| `port` | port | `443` | Server port |
| `udp` | bool | — | Enable UDP |
| `tls` | bool | — | Enable TLS |
| `skip_cert_verify` | bool | — | Skip TLS cert verification |
| `sni` | string | — | TLS SNI override |
| `servername` | string | — | Alias of `sni` used by some protocols |
| `alpn` | list(string) | — | TLS ALPN list (`h2`, `http/1.1`, `h3`) |
| `fingerprint` | string | — | Server-pinned TLS fingerprint |
| `client_fingerprint` | string | — | uTLS client fingerprint (`chrome`, `firefox`, etc.) |
| `ip_version` | enum | — | `dual` \| `ipv4` \| `ipv6` \| `ipv4-prefer` \| `ipv6-prefer` |
| `tfo` | bool | — | TCP fast open |
| `interface_name` | string | — | Bind to specific interface |
| `routing_mark` | string | — | fwmark for routing |
| `dialer_proxy` | string | — | Chain through another proxy by name |
| `multiplex` | bool | `false` | Enable smux |
| `multiplex_protocol` | string | — | smux protocol |
| `multiplex_max_connections` | int | — | — |
| `multiplex_min_streams` | int | — | — |
| `multiplex_max_streams` | int | — | — |
| `multiplex_padding` | bool | — | — |
| `multiplex_statistic` | bool | — | — |
| `multiplex_only_tcp` | bool | — | — |
| `other_parameters` | string (YAML) | — | Raw YAML fragment appended to the proxy entry |

### 3.2 Type-specific: `ss`

| Key | Type | Purpose |
|---|---|---|
| `cipher` | enum | SS cipher (aes-256-gcm, chacha20-ietf-poly1305, 2022-blake3-*, etc.) |
| `password` | string (secret) | Password |
| `obfs` | enum | `none` \| `http` \| `tls` \| `websocket` \| `shadow-tls` \| `restls` |
| `host` | string | obfs host header |
| `obfs_password` | string | shadow-tls / restls password |
| `obfs_version_hint` | string | restls version hint |
| `obfs_restls_script` | string | restls script URL |
| `mux` | bool | v2ray-plugin mux |
| `custom` | string | v2ray-plugin custom header |
| `path` | string | v2ray-plugin WS path |
| `udp_over_tcp` | bool | UDP-over-TCP |

### 3.3 Type-specific: `vmess`

| Key | Type | Purpose |
|---|---|---|
| `uuid` | string | VMess UUID |
| `alterId` | int | AlterId (use `0` for AEAD) |
| `securitys` | enum | Cipher (`auto` \| `aes-128-gcm` \| `chacha20-poly1305` \| `none`) |
| `xudp` | bool | XUDP multiplex |
| `packet_encoding` | enum | Packet encoding (`packet` \| `xudp` \| `none`) |
| `global_padding` | bool | — |
| `authenticated_length` | bool | — |
| `obfs_vmess` | enum | Transport (`none` \| `websocket` \| `http` \| `h2` \| `grpc`) |
| `path` | string | WS/HTTP path |
| `ws_opts_path` | string | WS path (alt) |
| `ws_opts_headers` | list(string) | WS headers (`Key: value`) |
| `max_early_data` | int | WS early-data bytes |
| `early_data_header_name` | string | Early-data header name |
| `http_path` | list(string) | HTTP paths |
| `keep_alive` | bool | HTTP keep-alive |
| `h2_path` | string | HTTP/2 path |
| `h2_host` | list(string) | HTTP/2 host headers |
| `grpc_service_name` | string | gRPC service name |
| `custom` | string | WS custom Host header |

### 3.4 Type-specific: `vless`

| Key | Type | Purpose |
|---|---|---|
| `uuid` | string | VLESS UUID |
| `xudp` | bool | — |
| `packet_addr` | bool | — |
| `packet_encoding` | enum | `xudp` \| `none` |
| `obfs_vless` | enum | Transport (`ws` \| `tcp` \| `grpc` \| `xhttp`) |
| `vless_flow` | enum | `` (empty) \| `xtls-rprx-vision` |
| `vless_encryption` | string | Encryption (usually `none`) |
| `ws_opts_path` | string | WS path |
| `ws_opts_headers` | list(string) | WS headers |
| `grpc_service_name` | string | gRPC service name |
| `reality_public_key` | string | REALITY public key |
| `reality_short_id` | string | REALITY short id |
| `xhttp_opts_path` | string | XHTTP path |
| `xhttp_opts_host` | string | XHTTP host |

### 3.5 Type-specific: `trojan`

| Key | Type | Purpose |
|---|---|---|
| `password` | string | Trojan password |
| `obfs_trojan` | enum | `none` \| `ws` |
| `trojan_ws_path` | string | WS path (when `obfs_trojan=ws`) |
| `trojan_ws_headers` | list(string) | WS headers |
| `grpc_service_name` | string | gRPC service name |

### 3.6 Type-specific: `hysteria2`

| Key | Type | Purpose |
|---|---|---|
| `password` | string | Hysteria2 password |
| `hysteria_up` | string | Upload bandwidth (e.g. `50 Mbps`) |
| `hysteria_down` | string | Download bandwidth |
| `hysteria_alpn` | list(string) | ALPN (e.g. `h3`) |
| `hysteria_obfs` | enum | `none` \| `salamander` |
| `hysteria_obfs_password` | string | Obfs password (salamander) |
| `hysteria_ca` | path | CA cert file |
| `hysteria_ca_str` | string | Inline CA cert |
| `initial_stream_receive_window` | int | QUIC flow control |
| `max_stream_receive_window` | int | — |
| `initial_connection_receive_window` | int | — |
| `max_connection_receive_window` | int | — |
| `ports` | string (portrange) | Port hopping range |
| `hysteria2_protocol` | enum | `udp` \| `faketcp` |
| `hop_interval` | int (seconds) | Port hop interval |

---

## 4. `groups` (0..N named sections)

One section per custom proxy group. Consumed by `yml_groups_set.sh` at Stage
4. All groups emit `include-all-proxies: true` in the generated YAML — there
is no per-server assignment (see `decision/0001-product-boundary.md`).

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `1` | Include in active config |
| `config` | list(string) | `all` | Target config(s) |
| `name` | string | required | Group name |
| `type` | enum | `select` | `select` \| `url-test` \| `fallback` \| `load-balance` |
| `filter` | string (regex) | — | Proxy-name include regex (emitted as `filter:`) |
| `exclude_filter` | string (regex) | — | **NEW**: proxy-name exclude regex (emitted as `exclude-filter:`) |
| `disable_udp` | bool | `false` | Disable UDP on this group |
| `strategy` | enum | — | `round-robin` \| `consistent-hashing` \| `sticky-sessions` (load-balance only) |
| `test_url` | URL | `http://cp.cloudflare.com/generate_204` | Health-check URL (url-test/fallback/load-balance) |
| `test_interval` | int (seconds) | `300` | Health-check interval |
| `tolerance` | int (ms) | `150` | url-test tolerance |
| `other_group` | list(string) | — | Reference other groups as members (by name) |
| `icon` | URL | — | Icon URL (for dashboard) |
| `other_parameters` | string (YAML) | — | Raw YAML fragment appended to the group entry |

**Renames vs OpenClash:**
- `policy_filter` → `filter` (direct Clash-native name)
- **new** `exclude_filter` added (no OpenClash equivalent)

**Dropped vs OpenClash:**
- `type = smart` (enum value removed)
- `uselightgbm`, `collectdata`, `policy_priority` (smart/LightGBM)
- `groups` list option (the regex list used to populate `proxies:`) — replaced
  by `include-all-proxies: true` + `filter` / `exclude_filter`
- `old_name` (rename helper, unused by the rewritten script)

---

## 5. `dns_servers` (0..N anonymous sections)

One section per DNS upstream. Emitted into `config.yaml` `dns:` block at Stage
7. Typical shipped defaults include a handful of `group=default` and
`group=nameserver` UDP / DoH entries.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `1` | Emit this entry |
| `group` | enum | `default` | `default` \| `nameserver` \| `fallback` |
| `type` | enum | `udp` | `udp` \| `tcp` \| `tls` \| `https` \| `quic` |
| `ip` | host | required | Server address, hostname, or DoH URL |
| `port` | port | — | Non-standard port |
| `interface` | string | — | Bind DNS query to interface (`Disable` = unset) |
| `direct_nameserver` | bool | `0` | Emit under `direct-nameserver:` |
| `node_resolve` | bool | `0` | Use for proxy-node resolution only |
| `disable_reuse` | bool | `0` | Disable connection reuse |
| `http3` | bool | `0` | Prefer HTTP/3 for DoH |
| `skip_cert_verify` | bool | `0` | TLS cert-verify skip (DoH/DoT/QUIC) |
| `ecs_subnet` | string | — | EDNS Client Subnet |
| `ecs_override` | bool | `0` | Override upstream ECS |
| `disable_ipv4` | bool | `0` | Disable IPv4 query on this server |
| `disable_qtype` | list(string) | — | Query types to refuse (e.g. `HTTPS`, `SVCB`) |
| `specific_group` | string | — | Target group name (regex) for selective routing |

**Dropped vs OpenClash:**
- `disable_ipv6` — IPv6 proxy out of scope in v1

---

## 6. `config_overwrite` (0..N named sections)

One section per overwrite source. Consumed at Stage 6 by init.d's
`overwrite_file()`, which emits `/tmp/yaml_overwrite.sh` and runs it against
the assembled config.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `0` | Apply this overwrite |
| `name` | string | required | Display name + on-disk filename (see below). `[%w][%w._%-]*` |
| `type` | enum | `inline` | `inline` (body authored in the CBI) \| `http` (remote URL, cron-fetched) |
| `config` | string | `all` | Scope: `all` or a specific config basename under `/etc/clashnivo/config/` |
| `url` | URL | — | Source URL (for `type=http`) |
| `order` | uint | `1` | Application order (lower runs first; later overwrites override earlier ones key-for-key) |
| `update_days` | int \| `off` | `off` | Auto-update day-of-month (`1`..`31` or `off`) |
| `update_hour` | int \| `off` | `off` | Auto-update hour (`0`..`23` or `off`) |
| `param` | string (`key=value;...`) | — | Semicolon-delimited knobs exported as env vars before the overwrite script runs |

**On-disk body**: `/etc/clashnivo/overwrite/<name>`. This matches the
OpenClash init.d path we forked from (`/etc/openclash/overwrite/<name>`) —
it's the path `overwrite_file()` actually reads. The file format is
OpenClash's `.ini`-style with `[General]` / `[Overwrite]` / `[YAML]` blocks;
the v1 CBI only exposes authoring of the `[YAML]` block (inline body is
saved wrapped as `[YAML]\n<body>`). Remote `http` sources are stored as
downloaded and may use any of the three sections.

---

## 7. `lan_ac_traffic` (0..N named sections)

Per-entry LAN AC traffic rules. Consumed by init.d `firewall_lan_ac_traffic()`
at Stage 10. The IPv6 branch of that function is dropped; the schema below is
IPv4 only.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `0` | Apply this rule |
| `comment` | string | `lan_ac_traffic` | Human-readable label |
| `src_ip` | ipmask | — | Source IP / CIDR |
| `src_port` | string | `0-65535` | Source port range |
| `proto` | enum | `both` | `tcp` \| `udp` \| `both` |
| `target` | enum | `return` | `return` (bypass proxy) \| `direct` \| `proxy` |
| `dscp` | string | — | DSCP match |
| `interface` | string | — | Source interface |
| `user` | string | — | Match by user (fw4 only) |

**Dropped vs OpenClash:**
- `family` (IPv4/IPv6/both) — IPv4 only in v1

---

## 8. `authentication` (singleton, anonymous)

Single `config authentication` section, access via `@authentication[0]`.
Populated by `uci-defaults/luci-clashnivo` on first boot. Used by the
dashboard / REST API proxy.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `1` | Enable auth |
| `username` | string | `Clash` | Dashboard username |
| `password` | string | auto-generated (8 alphanumeric) | Dashboard password |

---

## 9. `rule_provider` (0..N named sections)

One section per rule-set provider. Emitted at Stage 5 into the `rule-providers:`
block of `config.yaml` by the same script that prepends custom rules. Consumed
by Clash rules that reference the provider by name (e.g. `RULE-SET,my-geoip,Proxy`).

| Key | Type | Default | Purpose |
|---|---|---|---|
| `enabled` | bool | `1` | Emit this provider |
| `config` | list(string) | `all` | Target config filename(s) or `all` |
| `name` | string | required | Provider name (referenced from rules) |
| `type` | enum | `http` | `http` (remote) \| `file` (local upload) |
| `behavior` | enum | `classical` | `domain` \| `ipcidr` \| `classical` |
| `format` | enum | `yaml` | `yaml` \| `text` \| `mrs` |
| `url` | URL | — | Source URL (for `type=http`) |
| `path` | string | auto | Local cache path under `/etc/clashnivo/rule_provider/` |
| `interval` | int (seconds) | `86400` | Refresh interval (http only) |
| `size_limit` | int (bytes) | `0` | Max rule-set size; `0` = unlimited |
| `proxy` | string | — | Route the fetch through a named proxy/group |

Uploaded rule-set files live at `/etc/clashnivo/rule_provider/<name>.<ext>` and
are managed through the same CBI page as custom rules (Epic 3c). When
`type=http`, the file is cached automatically by Mihomo; when `type=file`, the
user uploads the content via the CBI file-manager widget.

**Dropped vs OpenClash:** none — this is a clean v1 addition.

---

## Deferred section types

These exist in OpenClash but are **not part of v1** (product-boundary decision):

- `proxy_provider` — external proxy-node YAML files. Deferred post-v1;
  subscriptions cover the common case.

When added (post-v1), update this document before landing code.

---

## Cut keys (reference)

This is the exhaustive cut list — do not add any of these to the schema,
`/etc/config/clashnivo`, `uci-defaults`, CBI models, or scripts. Each entry
maps back to an exclusion in `decision/0001-product-boundary.md`.

### IPv6 proxy (v1 deferred)

`ipv6_enable`, `ipv6_dns`, `ipv6_mode`, `enable_v6_udp_proxy`, `fakeip_range6`,
`stack_type_v6`, `lan_ac_black_ipv6s`, `lan_ac_white_ipv6s`, `wan_ac_black_ipv6s`,
`china_ip6_route`, `china_ip6_route_pass`, `chnr6_custom_url`, `lan_ip6`,
`local_network_pass_ipv6`, `chnroute6_pass`, `cn_port6`, `dns_servers.disable_ipv6`,
`lan_ac_traffic.family`.

### Chnroute / China IP split-routing

`china_ip_route`, `china_ip_route_pass`, `chnr_auto_update`,
`chnr_update_day_time`, `chnr_update_week_time`, `chnr_custom_url`,
`cndomain_custom_url`, `chnroute_pass`, `local_network_pass` (the
chnroute-specific list — the local-network bypass that is chnroute-independent
stays in firewall code, not UCI).

### Streaming unlock

`stream_auto_select`, `stream_auto_select_interval`,
`stream_auto_select_logic`, `stream_auto_select_expand_group`,
`stream_auto_select_close_con`, and every `stream_auto_select_<service>` /
`stream_auto_select_group_key_<service>` /
`stream_auto_select_region_key_<service>` /
`stream_auto_select_node_key_<service>` variant
(`netflix`, `disney`, `hbo_max`, `tvb_anywhere`, `prime_video`, `ytb`,
`dazn`, `paramount_plus`, `discovery_plus`, `bilibili`,
`google_not_cn`, `openai`).

### LightGBM / smart groups

`smart_enable`, `smart_collect`, `smart_collect_size`, `smart_collect_rate`,
`smart_policy_priority`, `smart_enable_lgbm`, `smart_prefer_asn`,
`auto_smart_switch`, `lgbm_auto_update`, `lgbm_custom_url`,
`lgbm_update_interval`, `groups.uselightgbm`, `groups.collectdata`,
`groups.policy_priority`, `groups.type = smart` (enum value), `skip_proxy_address`.

### Exotic server protocols

Entire `servers.type` values and their fields: `ssr`, `snell`, `sudoku`,
`ssh`, `socks5`, `http`, `wireguard`, `tuic`, `mieru`, `anytls`, `hysteria`
(v1 — keep only `hysteria2`), `masque`, `trusttunnel`, `dns`, `direct`.

### TUN-mode variants (fake-ip / redir-host only in v1)

`operation_mode` / `en_mode` values `redir-host-tun`, `fake-ip-tun`,
`redir-host-mix`, `fake-ip-mix`. `stack_type` is **deferred** (not cut)
because TUN is explicitly noted as a later epic in
`decision/0001-product-boundary.md`.

### Developer / debug / misc

`core_type`, `release_branch` (single-channel ship), `yacd_type` (single
dashboard pair ships), `update` (unused flag), `dashboard_forward_ssl` —
**actually kept**, do not confuse with dev settings. Developer-panel fields
from OpenClash's `settings.lua` developer/debug tabs (not individually listed
— the whole tab is dropped).

### yml_rules_change.sh positional args

`$4` (router_self_proxy rule injection flag), `$5` (router LAN IP), `$6` (NAT
type), `$7` (fake-ip mode for self-proxy), `$8`–`$13` (auto_smart_switch,
collectdata, sample_rate, policy_priority, uselightgbm, prefer_asn). The
init.d call site must pass only the surviving `$1`–`$3` plus the
CDN/url-test mods.

---

## Resolved decisions

**Q1 — `operation_mode` vs `en_mode` (resolved):** `en_mode` was the
original init.d key; `operation_mode` was added later in the CBI without
cleaning up the old name. OpenClash `/etc/config/openclash` sets `en_mode`
twice (a visible symptom of the confusion). **Decision: use `operation_mode`
everywhere** — both in scripts and CBI. `en_mode` is dropped entirely from
Clash Nivo.

**Q2 — Default port numbers (resolved):** bump all ports by `+100` from
OpenClash defaults to allow side-by-side coexistence:

| Key | Default |
|---|---|
| `http_port` | `7990` |
| `socks_port` | `7991` |
| `proxy_port` | `7992` |
| `mixed_port` | `7993` |
| `tproxy_port` | `7995` |
| `dns_port` | `7974` |
| `cn_port` | `9190` |

**Q3 — `dashboard_type` default (resolved):** `zashboard`. Both MetaCubeXD
and Zashboard ship; `zashboard` is the default.

**Q4 — `config_path` bootstrap (resolved):** init.d refuses to start with a
clear log message ("no subscription configured") when `config_path` is empty
or the target file does not exist. No fallback template. Consistent with the
"binary missing" error pattern.

---

## Summary

| Metric | Count |
|---|---|
| Singleton `clashnivo.config` keys (KEEP) | ~95 |
| Keys cut vs OpenClash | ~110+ (IPv6, chnroute, streaming, LightGBM, exotic protocols, TUN variants, dev/debug) |
| Section types (KEEP) | 9 |
| Section types (DEFERRED) | 1 (`proxy_provider`) |
| Server protocol types (KEEP) | 5 (ss, vmess, vless, trojan, hysteria2) |
| Server protocol types (CUT) | 14+ |
| Group types (KEEP) | 4 (select, url-test, fallback, load-balance) |
| Group types (CUT) | 1 (smart) |

---

## What next

With audit #2 settled, the pre-build audit gate is passed. Epic 0 scaffold
work can begin:
- `/etc/config/clashnivo` factory-default file derived from §1–§8 above.
- `uci-defaults/luci-clashnivo` — sets `dashboard_password`, `core_version`
  (arch detection), `default_resolvfile`, `disable_quic_go_gso` (kernel
  check), `@authentication[0]` entry.
- Every forked shell script's `uci_get_config` call sites must reference
  only keys declared here. A missing key is a bug in this document.
- CBI models (`settings.lua`, etc.) declare fields in the order of §1
  subsections.
