#!/bin/sh

uci_get_config() {
    local key="$1"
    uci -q get clashnivo.@overwrite[0]."$key" || uci -q get clashnivo.config."$key"
}
