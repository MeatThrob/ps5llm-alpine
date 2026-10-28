#!/bin/sh
# ram-valve: MONITOR ONLY as of 2026-10-19 (auto-restart removed).
# History: this valve restarted llama-server when MemAvailable dropped
# (<1GB idle / <400MB busy). Both paths fired on 5-minute cron ticks and
# killed in-flight prefills (23:25, 23:50, 00:05 PDT on 2026-10-19), then
# looped restarts while idle (<1GB), destroying the KV cache every 5 min.
# PS5LM Plus never restarts llama-server mid-conversation; llama.cpp manages
# host RAM itself (--cache-ram 0, --ctx-checkpoints 1) and the OS reclaims
# the mmap'd page cache. Restarts are manual only (ps5llm-tui / rc-service).
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
AVAIL=$(awk '$1=="MemAvailable:" {print $2; exit}' /proc/meminfo 2>/dev/null)
case "$AVAIL" in ''|*[!0-9]*) exit 0;; esac
# Log only when below the old idle threshold, to keep the log quiet.
[ "$AVAIL" -ge 1024000 ] && exit 0
BUSY=$(curl -s --max-time 8 http://127.0.0.1:8080/slots 2>/dev/null | grep -o '"is_processing":[a-z]*' | head -n 1)
logger -t ram-valve "monitor: avail=${AVAIL}kB slot=${BUSY:-unknown} (auto-restart disabled 2026-10-19)"
exit 0
