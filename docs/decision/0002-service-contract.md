# Service Contract

Status: Settled

## Purpose

Define the stable contract between the LuCI frontend (CBI models + controller +
views) and the backend (shell scripts + UCI config + Mihomo binary). Later work
may refactor internals freely as long as this contract is preserved.

---

## Contract Rule

The user-facing layer interacts with the backend exclusively through:
1. **UCI reads/writes** — all persistent settings are in `/etc/config/clashnivo`.
2. **Init.d actions** — start, stop, restart, reload via `/etc/init.d/clashnivo`.
3. **Shell scripts** — explicit, named scripts invoked by the controller.
4. **Log file reads** — `/tmp/clashnivo.log` and `/tmp/clashnivo_start.log`.
5. **Mihomo REST API** — status/proxy queries on the controller port.

The frontend must not directly modify YAML files, call iptables, or manipulate
the binary. All of that is the backend's responsibility.

---

## Identity

| Identity | Value |
|---|---|
| UCI config name | `clashnivo` |
| Config directory | `/etc/clashnivo/` |
| Subscription/config files | `/etc/clashnivo/config/<name>.yaml` |
| Active config pointer | `clashnivo.config.config_path` (UCI) |
| Core binary | `/etc/clashnivo/core/clash_meta` |
| Init.d service | `/etc/init.d/clashnivo` |
| Runtime log | `/tmp/clashnivo.log` |
| Startup log | `/tmp/clashnivo_start.log` |
| Mihomo REST API | `http://<lan-ip>:<cn_port>` (default port 9090) |
| Mihomo DNS port | `clashnivo.config.dns_port` (default 7874) |
| LuCI namespace | `admin/services/clashnivo` |

---

## Required Operations

### Service lifecycle

| Operation | How |
|---|---|
| Start | `/etc/init.d/clashnivo start` |
| Stop | `/etc/init.d/clashnivo stop` |
| Restart | `/etc/init.d/clashnivo restart` |
| Reload config (no stop) | `/etc/init.d/clashnivo reload` |
| Status (is it running?) | `pidof clash_meta` or Mihomo REST `GET /version` |

### Config assembly

| Operation | Script |
|---|---|
| Download/refresh all subscriptions | `clashnivo.sh` |
| Download single subscription | `clashnivo.sh <name>` |
| Rebuild groups/proxies from UCI | `yml_proxys_set.sh <config_path>` then `yml_groups_set.sh <config_path>` |
| Rebuild rules from UCI | `yml_rules_change.sh <config_path>` |
| Apply overwrite | called from `clashnivo.sh` via `ruby_merge` |

### Binary management

| Operation | Script |
|---|---|
| Download/update core | `clashnivo_core.sh` |
| Check installed version | `<binary> -v` |
| Validate config | `<binary> -t -d /etc/clashnivo -f <config>` |

### Config file management

| Operation | How |
|---|---|
| List available configs | glob `/etc/clashnivo/config/*.yaml` |
| Switch active config | write `clashnivo.config.config_path` in UCI, then reload |
| Upload new config | controller endpoint, saves to `/etc/clashnivo/config/` |
| Delete config | controller endpoint, removes file + clears UCI if was active |

---

## Error Model

| Category | Expected behaviour |
|---|---|
| Config validation failure | Binary does NOT start. Error written to startup log. Running instance (if any) is not disturbed. |
| Download failure | Raw file is not replaced. Existing config continues. Error logged. |
| YAML parse error | Same as download failure. Ruby parse errors are logged. |
| Binary missing | Start is blocked with a clear "core not installed" message. |
| Binary crash | procd restarts automatically. Watchdog script provides secondary recovery. |
| DNS revert failure | Logged. The next stop attempt will retry. |

---

## Status And Reporting

Minimum machine-readable state the frontend requires:

| Field | Source |
|---|---|
| `running` | `pidof clash_meta` → boolean |
| `active_config` | `clashnivo.config.config_path` UCI value |
| `mode` | `clashnivo.config.proxy_mode` UCI value (rule/global/direct) |
| `start_log_last_line` | last line of `/tmp/clashnivo_start.log` |
| `core_version` | `clash_meta -v` output |
| `api_reachable` | HTTP GET to `http://127.0.0.1:<cn_port>/version` |

These six fields are sufficient to render a meaningful status overview without
depending on the binary being running.

---

## Change Control

- Later tasks may refactor internals (script logic, YAML building, Ruby calls)
  freely if they preserve the operations and identities above.
- If a later task needs to add, remove, or rename a contract item, update this
  document first and note the reason.
- The UCI config name (`clashnivo`) and the init.d service name
  (`/etc/init.d/clashnivo`) are permanent — changing them would break existing
  installations.

## Notes

- The Mihomo REST API is not a clashnivo contract — it is upstream behaviour.
  The frontend may rely on it but should degrade gracefully if it is unreachable
  (binary not running, wrong port, etc.).
- procd integration means `start`/`stop`/`restart` go through the OpenWrt service
  manager. Direct `kill` is not an acceptable substitute.
