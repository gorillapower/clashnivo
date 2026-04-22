# OpenWrt in QEMU — local test environment

Status: Optional tooling. Not required for Epic 0, but recommended before
Epic 0 ships — the init.d script in particular can only be meaningfully
verified against a running OpenWrt system with fw4/nftables and procd.

## Why

Clash Nivo targets OpenWrt. Our dev machines run macOS. Without a router
on the desk, there is no way to confirm that `procd` launches the service
correctly, that `nft list ruleset` shows the expected chains after
`set_firewall()`, or that `uci commit clashnivo` round-trips the config.

QEMU lets us run a real OpenWrt system as a VM on macOS. Everything works
except the specific router hardware bits (kernel modules for a specific
SoC, USB device passthrough). For 95% of what we build — UCI, procd, fw4,
LuCI — it is faithful to a physical device.

## Prerequisites

- macOS with Homebrew
- ~500 MB disk for the image
- Terminal familiarity

## One-time setup

### 1. Install QEMU

```sh
brew install qemu
```

### 2. Download an OpenWrt x86_64 image

OpenWrt publishes images specifically for virtual machines. Use the
stable release (currently 23.05.x as of writing):

```sh
mkdir -p ~/openwrt-vm && cd ~/openwrt-vm
curl -LO https://downloads.openwrt.org/releases/23.05.5/targets/x86/64/openwrt-23.05.5-x86-64-generic-ext4-combined.img.gz
gunzip openwrt-23.05.5-x86-64-generic-ext4-combined.img.gz
```

### 3. Grow the disk (optional but recommended)

Default is 128 MB, which fills up fast once you install packages:

```sh
qemu-img resize -f raw openwrt-23.05.5-x86-64-generic-ext4-combined.img 1G
```

Then boot the VM once (next step) and run `opkg update && opkg install
resize2fs` on the VM side to actually use the space — or just skip this
and deal with it later.

### 4. Create a boot script

Save as `~/openwrt-vm/boot.sh`:

```sh
#!/bin/sh
qemu-system-x86_64 \
  -M q35 \
  -cpu max -accel tcg \
  -m 512 \
  -drive file=openwrt-23.05.5-x86-64-generic-ext4-combined.img,format=raw,if=virtio \
  -netdev user,id=n0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
  -device virtio-net-pci,netdev=n0 \
  -nographic
```

`chmod +x boot.sh`.

Key flags:
- `-accel tcg` is software emulation. Apple's Hypervisor Framework
  (`hvf`) only accelerates same-arch guests — an arm64 Mac cannot hvf-
  accelerate an x86_64 guest, and an Intel Mac running this x86_64
  image could swap in `-cpu host -accel hvf` for a large speedup.
  Everything works under TCG; boot is just slower (tens of seconds
  to login prompt).
- `-netdev user` is user-mode networking: the VM can reach the internet
  through your Mac's connection, no root required, no tap interfaces
- `hostfwd=tcp::2222-:22` forwards Mac's `localhost:2222` to the VM's
  SSH port, so you can `ssh root@localhost -p 2222`
- `hostfwd=tcp::8080-:80` forwards Mac's `localhost:8080` to LuCI, so
  you can open `http://localhost:8080` in Safari
- `-nographic` means no window — stdin/stdout is the VM console. Use
  Ctrl-A then X to quit. If you want a graphical console, drop this flag.

### 5. First boot — set root password, enable SSH, make the NIC a DHCP client

```sh
./boot.sh
```

Wait for the login prompt, then inside the VM:

```sh
passwd                  # set root password
/etc/init.d/dropbear enable
/etc/init.d/dropbear start

# OpenWrt's x86 image configures the single NIC as a static LAN (192.168.1.1).
# Under QEMU slirp there's only one NIC and it needs to be a DHCP client to
# pick up slirp's 10.0.2.15 lease — otherwise the hostfwd tunnel (host:2222 →
# guest 10.0.2.15:22) has nowhere to land and SSH times out at banner exchange.
# This is VM-only plumbing — a real OpenWrt router still wants the static LAN.
uci set network.lan.proto='dhcp'
uci delete network.lan.ipaddr
uci delete network.lan.netmask
uci commit network
/etc/init.d/network restart

# One-time opkg prereqs used by the rest of this doc (curl for Mihomo install,
# rsync for the push helper, luci-compat for the Lua LuCI controllers).
opkg update
opkg install curl rsync luci-compat
```

From another Mac terminal:

```sh
ssh root@127.0.0.1 -p 2222
```

Use `127.0.0.1` explicitly, not `localhost` — on some Macs (Tailscale MagicDNS,
custom `/etc/hosts`, etc.) `localhost` resolves to IPv6 `::1` first, and QEMU's
slirp hostfwd is IPv4-only.

If it works, you're set. Everything from here on you do over SSH.

## Dev loop

### Push your tree to the VM

Save as `~/dev/Personal/clashnivo/scripts/push-to-vm.sh`. This mirrors the
install rules in the package `Makefile` — `root/* → /` and
`luasrc/* → /usr/lib/lua/luci/` — so the LuCI app, rpcd ACL, ucitrack, and
uci-defaults trees all land where the runtime expects them:

```sh
#!/bin/sh
set -e
VM=root@127.0.0.1
PORT=2222
cd "$(git rev-parse --show-toplevel)"

SSH="ssh -p $PORT"

# No deletes — stale files on the VM need manual cleanup.

rsync -a -e "$SSH" root/etc/init.d/clashnivo      $VM:/etc/init.d/clashnivo
rsync -a -e "$SSH" root/usr/share/clashnivo/      $VM:/usr/share/clashnivo/
rsync -a -e "$SSH" root/usr/share/rpcd/           $VM:/usr/share/rpcd/
rsync -a -e "$SSH" root/usr/share/ucitrack/       $VM:/usr/share/ucitrack/ 2>/dev/null || true
rsync -a -e "$SSH" root/etc/uci-defaults/         $VM:/etc/uci-defaults/ 2>/dev/null || true
rsync -a -e "$SSH" root/etc/config/clashnivo      $VM:/etc/config/clashnivo 2>/dev/null || true
rsync -a -e "$SSH" luasrc/                        $VM:/usr/lib/lua/luci/

$SSH $VM "
  chmod +x /etc/init.d/clashnivo /usr/share/clashnivo/*.sh 2>/dev/null
  rm -rf /tmp/luci-* 2>/dev/null
  true
"
echo "Pushed."
```

`chmod +x scripts/push-to-vm.sh`.

### Test cycle

```sh
# On Mac
./scripts/push-to-vm.sh

# Then SSH in
ssh root@127.0.0.1 -p 2222

# Inside the VM
/etc/init.d/clashnivo start
logread | tail -50        # look at procd / service logs
cat /tmp/clashnivo.log    # look at our own log output
nft list ruleset | grep -A2 clashnivo   # inspect firewall chains
pidof mihomo              # did the core actually start?
uci show clashnivo        # did UCI round-trip cleanly?
/etc/init.d/clashnivo stop
nft list ruleset | grep clashnivo       # should be empty after stop
```

Without a loaded profile, `start` will exit at `Step 1: Get The Configuration
... [Error] Config Not Found` — mihomo won't launch, no nft chains will appear,
and `pidof mihomo` will be empty. That path verifies UCI round-trip + init.d
gating only. To exercise firewall + mihomo, set `clashnivo.config.enable=1`
and either import a subscription through LuCI or drop a valid profile into the
path clashnivo expects. The CLI-only test cycle above is useful for schema /
gating / teardown verification, not for the full start path.

## Installing Mihomo inside the VM

`clashnivo_core.sh` will download Mihomo on first start — but you can
shortcut this during dev:

```sh
# On the VM
mkdir -p /etc/clashnivo/core
cd /tmp
curl -LO https://github.com/MetaCubeX/mihomo/releases/download/v1.19.14/mihomo-linux-amd64-v1.19.14.gz
gunzip mihomo-linux-amd64-v1.19.14.gz
install -m 755 mihomo-linux-amd64-v1.19.14 /etc/clashnivo/core/mihomo
/etc/clashnivo/core/mihomo -v   # confirm it runs
```

## What this environment can and can't do

### Can
- Verify `/etc/init.d/clashnivo {start,stop,reload,restart}` behavior end-to-end
- Confirm nftables chain creation/teardown matches expectations
- Catch UCI schema bugs (unknown keys, type mismatches)
- Test that `revert_firewall` leaves zero residue
- Exercise the dnsmasq snapshot/restore cycle
- Verify Mihomo actually starts with our generated config
- Iterate LuCI UI pages at `http://127.0.0.1:8080/cgi-bin/luci`

### Can't
- Test MIPS-specific arch detection in `clashnivo_core.sh` (the VM is x86_64)
- Test fw3 / iptables (modern OpenWrt x86 images use fw4; to test fw3 you
  need an older image or a real router)
- Test the `small_flash_memory` branch (VM has plenty of disk)
- Test behaviour with a real ISP's DNS / PPPoE / VLAN config

## Packaging for real distribution (Epic 5, not now)

The `.ipk` format requires the OpenWrt SDK, which only builds on Linux.
On macOS, use Docker Desktop's Linux VM transparently:

```sh
docker run --rm -it \
  -v $(pwd):/home/build/openwrt/package/luci-app-clashnivo \
  openwrt/sdk:23.05-x86-64 \
  bash -c "./scripts/feeds update -a && make package/luci-app-clashnivo/compile"
```

The produced `.ipk` drops in `bin/packages/…/` and can be `scp`'d to the
VM and `opkg install`'d just like on a real router.

Not needed until we want to test the full install/uninstall lifecycle.

## Cleanup

Delete the disk image to reset. That's it — user-mode networking leaves
no artefacts on the Mac side.

## References

- OpenWrt VM documentation: <https://openwrt.org/docs/guide-user/virtualization/qemu>
- Mihomo releases: <https://github.com/MetaCubeX/mihomo/releases>
- QEMU hostfwd syntax: <https://www.qemu.org/docs/master/system/invocation.html>
