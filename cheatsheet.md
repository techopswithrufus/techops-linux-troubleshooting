# Linux Server Slow? 9-Step Troubleshooting Cheat Sheet

By **TechOps with Rufus**. All commands below only read data, unless a step says otherwise.

**Rule:** diagnose first, then act. Do not restart or kill anything until you know the cause.

## The 9 checks, in order

| # | Check | Commands |
|---|---|---|
| 1 | Scope | `hostname`, `date`, `uptime` |
| 2 | Load and CPU | `uptime`, `nproc`, `top` |
| 3 | Memory and swap | `free -m`, `vmstat 1 5`, `swapon --show` |
| 4 | Disk space | `df -h`, `df -i`, `du` |
| 5 | Disk I/O | `iostat -xz 1 3`, `iotop` |
| 6 | Processes | `ps`, `pgrep`, `pstree -p`, `lsof -p PID` |
| 7 | Network | `ss`, `ping`, `curl`, `dig` |
| 8 | Services and logs | `systemctl`, `journalctl` |
| 9 | Recent changes | `last`, `crontab`, package history |

## Step 1: Scope

Ask first: what is slow, since when, what changed, and is it everyone or one application?

```bash
hostname
date
uptime
```

## Step 2: Load and CPU

```bash
uptime
nproc
top            # press 1 = each core, P = sort by CPU, M = sort by memory, q = quit
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -6
mpstat -P ALL 1 3     # needs sysstat
```

**Load average greater than the number of cores means the CPU is busy or processes are waiting.**

| `top` field | Meaning | Problem sign |
|---|---|---|
| us | User programs | Above 80%: an application is using the CPU |
| sy | Kernel | High: heavy system calls or I/O |
| wa | Waiting for disk | Above 10 to 20%: a disk problem, go to step 5 |
| st | Stolen by hypervisor | Above 5%: a noisy neighbour on AWS or Azure |
| id | Idle | Near 0: no CPU left |

## Step 3: Memory and swap

```bash
free -m                 # look at "available", not "free"
vmstat 1 5
swapon --show
ps -eo pid,user,%mem,rss,etime,cmd --sort=-%mem | head -6
sudo dmesg -T | grep -i -E "out of memory|killed process"     # OOM killer
```

| `vmstat` column | Meaning | Problem sign |
|---|---|---|
| si, so | Memory swapped in and out per second | Steady above 0: the server is swapping |
| r | Processes waiting for CPU | Higher than the core count |
| b | Processes blocked on I/O | Above 0 repeatedly: a disk problem |
| wa | CPU waiting for disk | Above 10 to 20% |

## Step 4: Disk space

```bash
df -h                                   # Use% above 90% is a danger
df -i                                   # IUse% above 90%: too many tiny files
sudo du -h --max-depth=1 /var | sort -hr | head
sudo lsof +L1                           # deleted files still held open by a process
```

- **`df` says 100% but `du` shows much less?** A deleted file is still open. Find it with `sudo lsof +L1`, then restart or reload that service so it closes the file.
- Do not delete a file you have not identified. Empty a live log with `sudo truncate -s 0 <file>`, never `rm`.

## Step 5: Disk I/O

```bash
iostat -xz 1 3          # needs sysstat
sudo iotop -oPa         # which process is doing the I/O; q to quit
```

| `iostat` column | Meaning | Problem sign |
|---|---|---|
| %util | How busy the disk is | Near 100%: saturated |
| r_await, w_await | Average wait per read or write (ms) | Above 20 to 50 ms on SSD |
| aqu-sz | Requests waiting in the queue | Above 1 and rising: a backlog |

## Step 6: Processes

```bash
ps -ef | grep [j]ava                     # the [j] stops grep from listing itself
pgrep -a java
ps -p <PID> -o pid,etime,time,%cpu,%mem,cmd
ps -eo stat,pid,ppid,cmd | awk '$1 ~ /^Z/'    # zombie processes
ps -eo stat,pid,cmd | awk '$1 ~ /^D/'         # stuck waiting on disk or NFS
pstree -p                                      # who started this process?
sudo lsof -p <PID>                             # files and ports this process uses
```

Replace `java` and `<PID>` with your application and its process ID.

## Step 7: Network

```bash
ss -s                                   # connection summary
sudo ss -tulpn                          # what is listening
ss -H -tan state established | wc -l
ss -H -tan state close-wait | wc -l
ss -H -tan state time-wait | wc -l
ping -c 4 8.8.8.8
dig google.com | grep "Query time"
curl -o /dev/null -s -w "HTTP %{http_code} in %{time_total}s\n" http://localhost:8080
```

- **`ss` replaces the older `netstat`.** `netstat -tulnp` becomes `ss -tulnp`.
- **Many `close-wait`:** the application is not closing connections (an application bug).
- **Thousands of `time-wait`:** very high connection churn. Reuse connections with Keep-Alive or connection pooling. Above about 15,000 to 20,000, ports can run out.
- **Ping slow or DNS "Query time" above 100 ms:** a network or DNS problem, not a server problem.
- **`curl` `time_total` above 1 to 2 seconds** while CPU, memory and disk look fine: the problem is in the application or its database.

## Step 8: Services and logs

```bash
systemctl --failed --no-pager
systemctl status nginx --no-pager                     # replace nginx with your service
sudo journalctl -p err -n 50 --no-pager
sudo journalctl -u nginx --since "1 hour ago" --no-pager | tail -50
sudo tail -n 200 /var/log/syslog | grep -i -E "error|fail|timeout"
```

On RHEL and Amazon Linux the classic log file is `/var/log/messages`.

**Look for:** when the errors started (does it match when users complained?), the same error repeating, "timeout", "connection refused", "too many open files", "out of memory", "no space left".

## Step 9: Recent changes

```bash
last -n 10
last reboot | head -3
grep -E " install | upgrade " /var/log/dpkg.log | tail -10    # Ubuntu; RHEL: rpm -qa --last | head
sudo find /etc -type f -mtime -1
crontab -l
sudo ls -l /etc/cron.d
systemctl list-timers --no-pager
```

If a recent change matches the slowness, do not undo it on the spot. Tell the owner first, then roll back with approval.

## Save evidence before you change anything

```bash
mkdir -p ~/incident && cd ~/incident
date > info.txt; uptime >> info.txt; free -m >> info.txt; df -h >> info.txt
top -b -n 1 | head -30 > top.txt
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -20 > ps.txt
sudo journalctl -p err --since "1 hour ago" --no-pager > errors.txt
```

## Cause found? Safe first action

| Cause found | Safe first action |
|---|---|
| One process using too much CPU or memory | Tell the application owner, restart the service (not `kill -9`) in an agreed window |
| Disk full | Clean or rotate old logs, `truncate` large live logs, expand the volume if it keeps growing |
| Disk I/O saturated | Find the process with `iotop`, reschedule the heavy job, raise volume IOPS or throughput |
| Memory leak or OOM kill | Restart the service, set memory limits, raise a bug with the evidence you saved |
| Heavy swapping | Add RAM or reduce the application's heap size |
| DNS or network slow | Check resolver, security groups and routes; involve the network team |
| Recent change matches | Inform the owner and roll back with approval |
| Resources healthy but `curl` slow | Hand over to the application or database team with your timings and logs |

## Symptom quick guide

| Symptom | Check first | Command |
|---|---|---|
| Server feels slow overall | Load against CPU cores | `uptime` and `nproc` |
| App hangs but CPU is idle | Disk wait, or the app and database | `iostat -xz 1 3` and a timed `curl` |
| "No space left on device" | Disk space, then inodes | `df -h` and `df -i` |
| A process vanished | OOM killer | `sudo dmesg -T`, look for "killed process" |
| Site or SSH slow to connect | DNS and network | `dig`, `ping`, `ss -s` |
| Service will not start | Status and its log | `systemctl status` and `journalctl -u` |
| Slow right after a deploy | Recent changes | `last`, `dpkg.log`, `find /etc -mtime -1` |

## Cloud notes (AWS and Azure)

- Check CPU `st` (steal) in `top`.
- On AWS, t-series instances can be throttled when CPU credits run out. Check the CPU credit balance in CloudWatch.
- EBS and Azure disks have IOPS and throughput limits. A busy volume with low `%util` but slow responses can mean you hit that limit; check the volume's CloudWatch graphs.
- Azure VM sizes have their own limits too.
