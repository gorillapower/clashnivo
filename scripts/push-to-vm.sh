#!/bin/sh
set -e
VM=root@127.0.0.1
PORT=2222
cd "$(git rev-parse --show-toplevel)"

SSH="ssh -p $PORT"
RSYNC="rsync -a -e \"$SSH\""

# Mirrors the install rules in the package Makefile:
#   root/*    -> /                         (init.d, configs, usr/share trees)
#   luasrc/*  -> /usr/lib/lua/luci/        (controller, models, views)
# No deletes: stale files on the VM need manual cleanup.

rsync -a -e "$SSH" \
  root/etc/init.d/clashnivo \
  $VM:/etc/init.d/clashnivo

rsync -a -e "$SSH" \
  root/usr/share/clashnivo/ \
  $VM:/usr/share/clashnivo/

rsync -a -e "$SSH" \
  root/usr/share/rpcd/ \
  $VM:/usr/share/rpcd/

rsync -a -e "$SSH" \
  root/usr/share/ucitrack/ \
  $VM:/usr/share/ucitrack/ 2>/dev/null || true

rsync -a -e "$SSH" \
  root/etc/uci-defaults/ \
  $VM:/etc/uci-defaults/ 2>/dev/null || true

rsync -a -e "$SSH" \
  root/etc/config/clashnivo \
  $VM:/etc/config/clashnivo 2>/dev/null || true

rsync -a -e "$SSH" \
  luasrc/ \
  $VM:/usr/lib/lua/luci/

$SSH $VM "
  chmod +x /etc/init.d/clashnivo /usr/share/clashnivo/*.sh 2>/dev/null
  # Rebuild LuCI cache so new controllers/views are picked up on next request.
  rm -rf /tmp/luci-* 2>/dev/null
  true
"
echo "Pushed."
