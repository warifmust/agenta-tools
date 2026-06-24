#!/bin/bash
# SENTRI - System Monitor Tool (pre-formatted output)

# Date
DATE=$(date "+%A, %B %d %Y %I:%M %p")

# Uptime
UPTIME=$(uptime | awk -F'up ' '{print $2}' | awk -F', load' '{print $1}' | xargs)

# CPU
CPU_LINE=$(top -l 1 -s 0 | grep "^CPU usage")
CPU_USER=$(echo "$CPU_LINE" | grep -oE '[0-9.]+% user' | grep -oE '[0-9.]+')
CPU_SYS=$(echo "$CPU_LINE" | grep -oE '[0-9.]+% sys' | grep -oE '[0-9.]+')
CPU_IDLE=$(echo "$CPU_LINE" | grep -oE '[0-9.]+% idle' | grep -oE '[0-9.]+')
CPU_USED=$(echo "scale=1; 100 - $CPU_IDLE" | bc)

# Memory
MEM_LINE=$(top -l 1 -s 0 | grep "^PhysMem")
MEM_USED=$(echo "$MEM_LINE" | grep -oE '[0-9]+G used' | grep -oE '[0-9]+')

# Disk (main volume only)
DISK_LINE=$(df -h /System/Volumes/Data | tail -1)
DISK_SIZE=$(echo "$DISK_LINE" | awk '{print $2}')
DISK_USED=$(echo "$DISK_LINE" | awk '{print $3}')
DISK_AVAIL=$(echo "$DISK_LINE" | awk '{print $4}')
DISK_PCT=$(echo "$DISK_LINE" | awk '{print $5}')

# Top 5 processes by CPU
TOP_CPU=$(ps aux | sort -rk3 | awk 'NR>1 && $3+0 > 0 {
    n = split($11, parts, "/")
    name = parts[n]
    gsub(/[^a-zA-Z0-9._-]/, "", name)
    if (length(name) > 25) name = substr(name, 1, 25)
    if (name != "") printf "  * %-25s %.1f%% CPU\n", name, $3
}' | head -5)

# Network — auto-detect active interface (works on macOS and Linux)
NET_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $NF; exit}')
NET_IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
# macOS fallback
if [ -z "$NET_IP" ]; then
    NET_IFACE=$(route get 1.1.1.1 2>/dev/null | awk '/interface:/{print $2}')
    NET_IP=$(ifconfig "${NET_IFACE:-en0}" 2>/dev/null | awk '/inet /{print $2}' | head -1)
fi
if [ -z "$NET_IP" ]; then
    NET_IP=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '127.0.0.1' | head -1)
fi
NET_STATUS="${NET_IFACE:-unknown} active, ${NET_IP:-unavailable}"

# Output formatted report
echo "System Status -- $DATE"
echo ""
echo "CPU:     ${CPU_USED}% used (${CPU_USER}% user, ${CPU_SYS}% sys)"
echo "Memory:  ${MEM_USED}GB used / 16GB total"
echo "Disk:    ${DISK_USED} used / ${DISK_SIZE} total -- ${DISK_AVAIL} free (${DISK_PCT})"
echo ""
echo "Top Processes (CPU):"
echo "$TOP_CPU"
echo ""
echo "Network: $NET_STATUS"
echo "Uptime:  $UPTIME"
echo ""
# Health verdict based on disk usage
DISK_PCT_NUM=$(echo "$DISK_PCT" | tr -d '%')
if [ "$DISK_PCT_NUM" -ge 90 ]; then
    echo "Disk critically full. Immediate attention required. ❌"
elif [ "$DISK_PCT_NUM" -ge 75 ]; then
    echo "Disk space getting tight. ⚠️"
else
    echo "All systems nominal ✅"
fi
