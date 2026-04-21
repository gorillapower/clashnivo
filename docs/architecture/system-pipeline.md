# System Pipeline

Status: Settled

## Core Concept

The UI does not directly control the proxy. It configures a pipeline that
assembles a `config.yaml`, which the Mihomo (Clash Meta) binary reads and runs.
Every setting the user changes ultimately affects what ends up in that file.

```
User (LuCI UI)
      │
      ▼
UCI config (/etc/config/clashnivo)
      │
      ├─── Subscription URLs ──────────────────────────────────────────────┐
      │                                                                     │
      │    ┌──────────────── ASSEMBLY PIPELINE ──────────────────────┐     │
      │    │                                                          │     │
      ├───►│ 1. Download subscription YAML                           │◄────┘
      ├───►│ 2. Apply node keyword filter (include/exclude by regex) │
      ├───►│ 3. Inject custom proxies (ruby_cover proxies:)          │
      ├───►│ 4. Inject custom groups  (ruby_cover proxy-groups:)     │
      ├───►│ 5. Prepend custom rules  (ruby arr_add rules:)          │
      ├───►│ 6. Apply config overwrite (ruby_merge deep merge)       │
      │    │ 7. Write global settings (ports, mode, DNS)             │
      │    │                                                          │
      │    └──────────────────────────┬───────────────────────────────┘
      │                               │
      │                               ▼
      │              /etc/clashnivo/config/<name>.yaml
      │                      (assembled config)
      │                               │
      │                               ▼
      │              Validate: clash_meta -t -d /etc/clashnivo -f config.yaml
      │                               │
      │                               ▼
      └──────────────────────► Mihomo binary starts
                                      │
                       ┌──────────────┴──────────────┐
                       ▼                             ▼
                DNS interception             Traffic interception
                (dnsmasq or fw4)             (iptables/nftables)
                       │                             │
                       └──────────────┬──────────────┘
                                      ▼
                              LAN devices proxied
```

---

## Stage-by-Stage Breakdown

### Stage 0 — UCI as the source of truth

All persistent user settings live in `/etc/config/clashnivo` as UCI. There are
several section types:

| UCI section type | What it stores |
|---|---|
| `clashnivo 'config'` | Global settings: ports, proxy mode, DNS redirect mode, log level, etc. |
| `config_subscribe` | One entry per subscription: URL, name, keyword filter, schedule |
| `servers` | Custom proxy server definitions (one UCI section per server) |
| `groups` | Custom proxy group definitions (one UCI section per group) |
| `dns_servers` | DNS upstream entries (nameserver/fallback groups) |
| `config_overwrite` | YAML overwrite snippets or remote URLs |

The LuCI CBI models read and write UCI. Nothing else is directly mutated by the UI.

---

### Stage 1 — Subscription download

Triggered by: manual refresh, scheduled cron, or first-ever start.

`clashnivo.sh` iterates each `config_subscribe` UCI section. For each enabled
subscription:

1. Downloads the YAML from the subscription URL using curl, writing to `/tmp/<name>.yaml`.
2. Validates the download: checks YAML is parseable (Ruby YAML.load), checks it
   contains a `proxies:` or `proxy-providers:` key. Rejects if either check fails.
3. Diffs against the existing stored config. If unchanged, skips.
4. If changed (or new), runs `config_cus_up` which applies keyword node filtering
   (see Stage 2), then moves the result to `/etc/clashnivo/config/<name>.yaml`.
5. If the updated file is the currently active config, sets `restart=1` to trigger
   a reload.

**Important:** There is no separate "raw subscription cache". The file at
`/etc/clashnivo/config/<name>.yaml` is the base config. It is overwritten by each
new subscription fetch, then modified in-place by the assembly pipeline on startup.
The customisations (custom servers/groups/rules/overwrite) are always re-applied
from UCI on every start/reload — they are never permanently baked into the stored
subscription file.

---

### Stage 2 — Node keyword filtering

Applied immediately after download, before storing.

The `server_key_match()` function builds a regex from the per-subscription
`keyword` (include) and `ex_keyword` (exclude) UCI fields. Ruby then iterates
the `proxies:` list in the downloaded YAML and removes nodes whose names don't
match the include regex or do match the exclude regex. Also sets `filter:` and
`exclude-filter:` on any `proxy-providers:` entries.

This stage does not affect custom servers added via the custom-servers form —
those are always injected regardless.

---

### Stage 3 — Custom proxy injection (`yml_proxys_set.sh`)

Triggered at service start/reload.

Reads every enabled `servers` UCI section and emits a `proxies:` YAML block to
`/tmp/yaml_servers.yaml`. Each server type (SS, VMess, VLess, Trojan, Hysteria2)
has its own YAML template. Then `ruby_cover` replaces the `proxies:` key in the
active config file with the combined set: subscription proxies + custom proxies.

Deduplication: if a custom server has the same `name` as a subscription proxy,
the subscription one takes precedence (it's already in the base).

---

### Stage 4 — Group injection (`yml_groups_set.sh`)

Same pattern as Stage 3 but for `proxy-groups:`. Reads enabled `groups` UCI
sections (both subscription-imported and custom), emits to `/tmp/yaml_groups.yaml`,
then `ruby_cover` replaces the entire `proxy-groups:` key in the active config.

**All groups in classnivo use `include-all-proxies: true`.** Rather than
manually listing which proxies belong to a group, every group automatically
includes every proxy in the assembled config (subscription proxies + custom
servers). Groups use an optional `filter:` regex to narrow the set (e.g.
`(?i)hk|hong.?kong`), and an optional `exclude-filter:` to exclude matches.

This is a deliberate deviation from OpenClash's manual-assignment model. It means:
- Custom servers appear in every group that doesn't filter them out.
- Subscription proxies appear in every group that doesn't filter them out.
- No per-server "which groups does this server belong to?" form field needed.
- Adding a new server from any source is automatically visible in all groups.

---

### Stage 5 — Custom rules injection (`yml_rules_change.sh`)

Reads custom rules from:
- The `openclash_custom_rules.list` file (plain text, one rule per line)
- Optionally `openclash_custom_rules_2.list`

Prepends these rules to the `rules:` array in the config using `ruby_arr_add`.
Also optionally prepends BT/PT DIRECT rules and process-name DIRECT rules.

"Prepend" means custom rules are evaluated first, before subscription rules. This
is the key invariant for custom rules: they always win.

---

### Stage 6 — Config overwrite (`ruby_merge`)

The overwrite is a YAML snippet that is deep-merged on top of the assembled config.
It runs last, so it can override anything — including fields set by Stages 3–5.

Source: UCI `config_overwrite` sections. Can be:
- An inline YAML text field typed in the UI.
- A remote URL downloaded and cached (with optional auto-update schedule).
- Multiple overwrite sections applied in order.

`ruby_merge` does a deep (recursive) hash merge, not a shallow replace. Arrays at
the top level (proxies, rules, etc.) are replaced, not concatenated.

**Use case:** A power user who knows exactly what they want. E.g., overwrite the
entire `dns:` block, or add a top-level `tun:` section that isn't exposed in the UI.

---

### Stage 7 — Global settings written into config

Ports, proxy mode (rule/global/direct), external-controller address, log level,
and the DNS block (built from UCI `dns_servers` sections) are written into the
config YAML before the binary starts.

The DNS block structure in config.yaml:
```yaml
dns:
  enable: true
  listen: 0.0.0.0:7874
  enhanced-mode: fake-ip          # or redir-host
  fake-ip-range: 198.18.0.0/15
  nameserver:
    - udp://114.114.114.114       # from UCI dns_servers group=nameserver
  fallback:
    - https://dns.google/dns-query  # from UCI dns_servers group=fallback
  fallback-filter:
    geoip: true
```

---

### Stage 8 — Validation and binary start

The assembled config is validated:
```sh
clash_meta -t -d /etc/clashnivo -f config.yaml
```
If validation fails, the startup aborts and logs the error. The old running
instance (if any) continues running.

If valid, the binary is launched via procd:
```sh
procd_set_param command /etc/clashnivo/core/clash_meta
procd_append_param command -d /etc/clashnivo -f /etc/clashnivo/config/<name>.yaml
```
procd monitors the process and restarts it on crash.

---

### Stage 9 — DNS interception

Two modes:

**Dnsmasq redirect (default):** The init script modifies the `dhcp` UCI config to
point dnsmasq's upstream at `127.0.0.1#<dns_port>`. All DNS queries from LAN
devices go through dnsmasq → Mihomo DNS. On stop, these changes are reverted and
the original dnsmasq config is restored.

**Firewall redirect:** An nftables/iptables rule redirects UDP port 53 directly to
Mihomo's DNS port, bypassing dnsmasq entirely.

---

### Stage 10 — Traffic interception (iptables/nftables)

The `set_firewall()` function creates chains and rules for transparent proxying.
The approach varies by proxy mode:

**Redir-host / fake-ip (non-TUN):**
- iptables NAT: `REDIRECT` TCP traffic from LAN (excluding private ranges) to
  Clash's redir port (default 7892).
- iptables mangle: `TPROXY` UDP traffic to Clash's tproxy port (default 7895).
- Clash's DNS returns either real IPs (redir-host) or fake IPs (fake-ip) for
  proxied domains. The iptables rules capture that traffic transparently.

**TUN mode:**
- Clash creates a `utun` virtual network interface.
- ip route rules redirect all non-local traffic into the TUN interface.
- Clash processes it at L3, routing to proxies per the rule set.

**Firewall rules survive firewall restarts** by being registered as a firewall
include at `/var/etc/clashnivo.include`, which calls
`/etc/init.d/clashnivo reload firewall` when fw3/fw4 reloads.

**LAN access control** (black/whitelist by IP or MAC) is applied as nftables sets
(`lan_ac_black_ips`, `lan_ac_white_ips`, etc.) consulted before the main redirect
rules.

---

## What `config.yaml` actually is

The final assembled `config.yaml` is a standard Mihomo/Clash YAML config:

```
port: 7890              ← HTTP proxy
socks-port: 7891        ← SOCKS5 proxy
mixed-port: 7893        ← HTTP+SOCKS5
redir-port: 7892        ← transparent redir (redir-host)
tproxy-port: 7895       ← transparent tproxy (UDP)
allow-lan: true
mode: rule              ← rule / global / direct
log-level: info
external-controller: 0.0.0.0:9090  ← REST API for dashboard
external-ui: /usr/share/clashnivo/ui/metacubexd

dns:
  (see Stage 7)

proxies:
  (subscription proxies + custom servers from UCI)

proxy-groups:
  (subscription groups + custom groups from UCI)

proxy-providers:
  (subscription proxy-providers, if any)

rule-providers:
  (from subscription)

rules:
  (custom rules prepended first, then subscription rules)
```

The Mihomo binary reads this file, sets up its proxy engine, and exposes:
- Proxy ports (HTTP, SOCKS5, mixed) for applications that need explicit config.
- Transparent proxy (via iptables redirect) for LAN devices with no explicit config.
- REST API on the controller port for the dashboard and the LuCI status widgets.

---

## The dashboard

The external dashboard (MetaCubeXD, Zashboard) is a pre-built SPA served as
static files from `/usr/share/clashnivo/ui/`. It connects to Mihomo's REST API
directly from the browser. It is NOT a LuCI page — the user opens it separately
(or via a link in the LuCI overview). It provides:
- Real-time proxy selection / switching.
- Connection log and active connection table.
- Speed/traffic graphs.
- Proxy latency testing.

The LuCI UI provides settings and management. The dashboard provides runtime
visibility. Both access the same Mihomo instance.

---

## Stop / cleanup

On `stop`, the init script:
1. Sends SIGTERM to the Mihomo process (procd handles this).
2. Flushes and removes the iptables/nftables chains it created.
3. Calls `revert_dns()` to restore dnsmasq to its original upstream settings.
4. Removes the dnsmasq conf-dir files it wrote.
5. Commits the reverted dhcp/clashnivo UCI state.

This means a clean stop leaves the router in exactly the same networking state as
before Clashnivo started.

---

## Key invariants

1. **Subscription files are never permanently modified by the UI.** Any inline
   edits via the UI (custom servers/groups/rules) are stored in UCI and injected
   at runtime. The next subscription refresh replaces the base and the pipeline
   re-runs cleanly.

2. **Config assembly always runs from UCI, not from the previous assembled file.**
   Stage 3–6 always pull from UCI at startup time. There is no "previous assembled
   state" that accumulates changes.

3. **Validation gates the start.** If the assembled config fails `clash_meta -t`,
   the binary does not start. The error is logged. The old running instance, if
   any, is not disturbed.

4. **Stop is fully reversible.** All DNS and firewall changes are tracked and
   reverted on stop. No permanent system-level changes are made.

5. **Coexistence.** Clashnivo uses distinct UCI config, distinct paths, distinct
   iptables chain names (`CLASHNIVO` prefix), and distinct ports from OpenClash.
   Both can run simultaneously without conflict.
