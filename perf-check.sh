#!/bin/bash
# perf-check.sh: read-only snapshot of a slow Linux server
# Part of the "Linux Performance Troubleshooting" series by TechOps with Rufus.
#
# This script only READS data. It does not restart, kill, delete or change anything.
# Run:  sudo bash perf-check.sh | tee perf-$(hostname)-$(date +%F_%H%M).txt
#
# Optional tools (the script tells you if one is missing):
#   iostat -> sudo apt install sysstat   (RHEL / Amazon Linux: sudo yum install sysstat)

section() { echo; echo "=== $1 ==="; }

section "TIME, UPTIME, LOAD"
date
uptime
echo "CPU cores: $(nproc)"

section "TOP 5 BY CPU"
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -6

section "TOP 5 BY MEMORY"
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%mem | head -6

section "MEMORY"
free -m

section "VMSTAT (si/so = swapping, wa = disk wait)"
vmstat 1 3

section "DISK SPACE"
df -hT | grep -v tmpfs

section "INODES"
df -i | grep -v tmpfs

section "DISK I/O"
if command -v iostat >/dev/null; then
  iostat -xz 1 2
else
  echo "iostat not found: sudo apt install sysstat"
fi

section "ZOMBIE AND D-STATE PROCESSES"
ps -eo stat,pid,ppid,cmd | awk '$1 ~ /^(Z|D)/'

section "CONNECTIONS"
if command -v ss >/dev/null; then
  ss -s
  echo "ESTABLISHED: $(ss -H -tan state established | wc -l)"
  echo "CLOSE-WAIT:  $(ss -H -tan state close-wait | wc -l)"
  echo "TIME-WAIT:   $(ss -H -tan state time-wait | wc -l)"
else
  echo "ss not found: install the iproute2 package"
fi

section "FAILED SERVICES"
if command -v systemctl >/dev/null; then
  systemctl --failed --no-pager
else
  echo "systemctl not found (this server does not use systemd)"
fi

section "RECENT ERRORS (journal)"
if command -v journalctl >/dev/null; then
  journalctl -p err -n 15 --no-pager
else
  echo "journalctl not found: check /var/log/syslog or /var/log/messages"
fi

section "OOM KILLS"
dmesg -T 2>/dev/null | grep -i -E "out of memory|killed process" | tail -5

section "LAST LOGINS AND REBOOT"
last -n 5
last reboot | head -2
