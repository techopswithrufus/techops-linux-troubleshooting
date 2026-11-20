# Linux Performance Troubleshooting (Tamil series)

Companion files for the **TechOps with Rufus** YouTube series on troubleshooting a slow Linux server. The explanations are in Tamil, with English technical terms.

## Videos

| Part | Topics | Link |
|---|---|---|
| Part 1 | Scope, load and CPU, memory, swap, OOM killer | https://youtu.be/8EcXrq7kayg |
| Part 2 | Disk space, disk I/O, processes | https://youtu.be/YQsenqCQZno |
| Part 3 (final) | Network, services and logs, recent changes | https://youtu.be/rh22lL-IPz0 |

## What is in this repository

| File | What it is |
|---|---|
| [`cheatsheet.md`](cheatsheet.md) | The full 9-step checklist with every command, what to look for, and what to do next |
| [`perf-check.sh`](perf-check.sh) | One script that takes a read-only snapshot of a slow server |

## Run the script

```bash
sudo bash perf-check.sh | tee perf-$(hostname)-$(date +%F_%H%M).txt
```

The script **only reads data**. It does not restart, kill, delete or change anything. Still, read it before you run it on a server you care about, and try it on a test server first.

It uses `iostat` from the `sysstat` package. If it is missing, the script tells you how to install it:

```bash
sudo apt install sysstat        # Ubuntu / Debian
sudo yum install sysstat        # RHEL / Amazon Linux
```

## The 9 checks

1. Scope
2. Load and CPU
3. Memory and swap
4. Disk space
5. Disk I/O
6. Processes
7. Network
8. Services and logs
9. Recent changes

**Rule:** diagnose first, then act. Do not restart or kill anything until you know the cause.

## Disclaimer

Commands are provided for learning and troubleshooting. Test them in a lab before using them on production systems. Thresholds in the cheat sheet (for example "above 90%") are rules of thumb, not guarantees.

## About

**TechOps with Rufus**: Linux, AWS, Terraform, Docker and Kubernetes in Tamil. Subscribe on YouTube for the next series.

## Licence

MIT. See [`LICENSE`](LICENSE).
