# Backend Layers

Status: Settled

## Purpose

Define the layered mental model of the clashnivo backend — how LuCI, UCI,
shell scripts, and the Mihomo binary relate to each other.

---

## Layer Diagram

```
┌─────────────────────────────────────────┐
│  LuCI (browser)                         │  ← user interaction
│  CBI forms, AJAX widgets, views         │
└──────────────┬──────────────────────────┘
               │ reads/writes UCI
               │ calls init.d actions
               │ calls named shell scripts
               │ reads log files
               ▼
┌─────────────────────────────────────────┐
│  OpenWrt layer                          │
│  UCI config  /etc/config/clashnivo      │  ← persistent settings store
│  init.d      /etc/init.d/clashnivo      │  ← service lifecycle (procd)
│  Shell scripts  /usr/share/clashnivo/   │  ← all the work happens here
└──────────────┬──────────────────────────┘
               │ assembles + writes
               ▼
┌─────────────────────────────────────────┐
│  config.yaml  /etc/clashnivo/config/    │  ← Mihomo reads this on start
└──────────────┬──────────────────────────┘
               │ starts binary
               ▼
┌─────────────────────────────────────────┐
│  Mihomo binary  (clash_meta)            │  ← the actual proxy engine
│  REST API  :9090                        │  ← dashboard + status queries
│  DNS listener  :7874                    │
│  TProxy  :7895                          │
└──────────────┬──────────────────────────┘
               │ intercepts traffic
               ▼
         LAN device traffic
```

---

## What Each Layer Does

### LuCI (frontend)

CBI models render forms that read and write UCI. JavaScript widgets
(`status.htm`, `toolbar_show.htm`) poll AJAX endpoints on the LuCI
controller. The controller calls init.d actions and named shell scripts
in response to user actions. LuCI never touches YAML files, iptables,
or the binary directly — that is the backend's job.

### UCI (`/etc/config/clashnivo`)

The single source of truth for all persistent settings. No logic lives
here — it is a key-value store. Scripts read UCI at runtime; LuCI reads
and writes it via the `uci` command or CBI. See `system-pipeline.md`
for the section types.

### Shell scripts (`/usr/share/clashnivo/`)

All the work. Four functional groups:

| Group | Scripts | Job |
|---|---|---|
| Orchestrator | `clashnivo.sh` | Called by init.d. Downloads subscriptions, drives the full assembly pipeline, calls all `yml_*.sh` scripts in order |
| Pipeline workers | `yml_proxys_set.sh`, `yml_groups_set.sh`, `yml_rules_change.sh` | Each reads UCI, emits a YAML block, splices it into the active config |
| YAML tools | `ruby.sh`, `YAML.rb` | `ruby_cover` replaces a YAML key in-place, `ruby_merge` deep-merges two YAML files, `ruby_arr_add` prepends to a YAML array. Called by pipeline workers |
| Asset management | `clashnivo_core.sh`, GEO scripts | Download and update the binary and GEO data files independently of the pipeline |

### config.yaml (`/etc/clashnivo/config/`)

The assembled Mihomo config. A derived artefact — never edited by hand
or by the UI. Regenerated from UCI on every start/reload. Validated with
`clash_meta -t` before the binary starts.

### Mihomo binary

The proxy engine. Reads `config.yaml` once on start. Exposes a REST API
(`/version`, `/proxies`, `/connections`, etc.) used by the external
dashboard and by LuCI status widgets for liveness checks. Not involved
in configuration — it only consumes the finished config file.

---

## Key Invariants

- **LuCI ↔ backend boundary is UCI + init.d + named scripts.** Anything
  outside this boundary is an implementation detail the frontend must not
  depend on.
- **Mihomo REST API is for status and runtime control only.** Group
  selection, connection monitoring, latency tests. Not for persistent
  configuration — that lives in UCI.
- **config.yaml is always regenerated from UCI.** There is no accumulated
  state in the file between runs.
