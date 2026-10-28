#!/bin/sh
# wifi-watchdog: cron every 2 min. If the gateway is unreachable, re-run
# the boot-time WiFi restore. Silent no-op when the network is healthy.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
_gw=$(ip route 2>/dev/null | grep '^default' | awk '{print $3}' | head -1)
[ -n "$_gw" ] && ping -c 2 -W 3 "$_gw" >/dev/null 2>&1 && exit 0
logger -t wifi-watchdog "gateway ${_gw:-unknown} unreachable; running wifi-restore"
[ -x /etc/local.d/wifi-restore.start ] && /etc/local.d/wifi-restore.start
exit 0
